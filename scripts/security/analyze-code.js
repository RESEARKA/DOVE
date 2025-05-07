// SPDX-License-Identifier: MIT
// Security analysis script for DOVE contracts

const fs = require('fs');
const path = require('path');

// Patterns to check for
const securityChecks = [
  {
    name: 'Reentrancy',
    pattern: /(_transfer|transfer|send|call).*\(\s*[^)]*\)/g,
    check: (code, match) => {
      // Check if there's a nonReentrant modifier or ReentrancyGuard
      if (code.includes('nonReentrant') || code.includes('ReentrancyGuard')) {
        return { safe: true, reason: 'Protected by nonReentrant modifier' };
      }
      return { 
        safe: false, 
        reason: 'Potential reentrancy in external calls without nonReentrant protection' 
      };
    }
  },
  {
    name: 'Unchecked Return Values',
    pattern: /(\.call|\.send)\{[^}]*\}\([^;]*\)/g,
    check: (code, match) => {
      // Check if there's a return value check
      const nextChars = code.substring(code.indexOf(match) + match.length, code.indexOf(match) + match.length + 20);
      if (nextChars.includes('require') || nextChars.includes('if') || match.includes('require')) {
        return { safe: true, reason: 'Return value is checked' };
      }
      return { 
        safe: false, 
        reason: 'Unchecked return value from low-level call' 
      };
    }
  },
  {
    name: 'Integer Overflow/Underflow',
    pattern: /([^\s]+\s*[\+\-\*\/]\s*[^\s;]+)/g,
    check: (code, match) => {
      // Check if using SafeMath or Solidity 0.8+
      if (code.includes('pragma solidity 0.8') || code.includes('SafeMath')) {
        return { safe: true, reason: 'Protected by Solidity 0.8+ built-in overflow checks' };
      }
      return { 
        safe: false, 
        reason: 'Arithmetic operation without overflow protection' 
      };
    }
  },
  {
    name: 'Access Control',
    pattern: /(function\s+\w+\s*\([^)]*\)\s*(public|external))/g,
    check: (code, match) => {
      // Check if has onlyOwner or other access modifier
      const functionCode = code.substring(code.indexOf(match), code.indexOf(match) + 100);
      if (functionCode.includes('onlyOwner') || 
          functionCode.includes('onlyAdmin') || 
          functionCode.includes('only') || 
          functionCode.includes('require(msg.sender')) {
        return { safe: true, reason: 'Protected by access control' };
      }
      // Skip view/pure functions
      if (functionCode.includes('view') || functionCode.includes('pure')) {
        return { safe: true, reason: 'View/pure function does not modify state' };
      }
      return { 
        safe: false, 
        reason: 'Public/external function without access control' 
      };
    }
  },
  {
    name: 'Timestamp Dependence',
    pattern: /(block\.timestamp|now)/g,
    check: (code, match) => {
      // Check if timestamp is used in a critical operation
      const surroundingCode = code.substring(
        Math.max(0, code.indexOf(match) - 50),
        code.indexOf(match) + 100
      );
      if (surroundingCode.includes('require') || surroundingCode.includes('if')) {
        return { 
          safe: false, 
          reason: 'Timestamp used in critical decision making - could be manipulated by miners' 
        };
      }
      return { safe: true, reason: 'Timestamp used but not in critical decision logic' };
    }
  },
  {
    name: 'Uniswap V3 Pool Initialization',
    pattern: /(createPool|createNewPool|initializePool)/g,
    check: (code, match) => {
      // Check for sqrtPriceX96 initialization
      const surroundingCode = code.substring(
        Math.max(0, code.indexOf(match) - 100),
        code.indexOf(match) + 200
      );
      if (!surroundingCode.includes('sqrtPriceX96')) {
        return { 
          safe: false, 
          reason: 'Pool initialization without proper sqrtPriceX96 value' 
        };
      }
      return { safe: true, reason: 'Pool initialized with sqrtPriceX96' };
    }
  },
  {
    name: 'Uniswap V3 Tick Spacing',
    pattern: /(FEE_TIER|feeTier|fee)/g,
    check: (code, match) => {
      const surroundingCode = code.substring(
        Math.max(0, code.indexOf(match) - 100),
        code.indexOf(match) + 200
      );
      if (surroundingCode.includes('500') && !surroundingCode.includes('tickSpacing')) {
        return { 
          safe: false, 
          reason: 'Using 0.05% fee tier without specifying tick spacing of 10' 
        };
      }
      if (surroundingCode.includes('3000') && !surroundingCode.includes('tickSpacing')) {
        return { 
          safe: false, 
          reason: 'Using 0.3% fee tier without specifying tick spacing of 60' 
        };
      }
      if (surroundingCode.includes('10000') && !surroundingCode.includes('tickSpacing')) {
        return { 
          safe: false, 
          reason: 'Using 1% fee tier without specifying tick spacing of 200' 
        };
      }
      return { safe: true, reason: 'Proper fee tier and tick spacing configuration' };
    }
  },
  {
    name: 'Slippage Protection',
    pattern: /(addLiquidity|swap|exactInputSingle|exactInput)/g,
    check: (code, match) => {
      const surroundingCode = code.substring(
        Math.max(0, code.indexOf(match) - 100),
        code.indexOf(match) + 200
      );
      if (!surroundingCode.includes('slippage') && 
          !surroundingCode.includes('amountOutMin') && 
          !surroundingCode.includes('amountInMax')) {
        return { 
          safe: false, 
          reason: 'Liquidity or swap operation without slippage protection' 
        };
      }
      return { safe: true, reason: 'Includes slippage protection' };
    }
  },
  {
    name: 'Token Approval Security',
    pattern: /(approve|safeApprove)/g,
    check: (code, match) => {
      if (match.includes('safeApprove')) {
        return { safe: true, reason: 'Using safeApprove from SafeERC20' };
      }
      // Check if approval is type(uint256).max
      const surroundingCode = code.substring(
        Math.max(0, code.indexOf(match) - 20),
        code.indexOf(match) + 50
      );
      if (surroundingCode.includes('type(uint256).max') && !code.includes('_resetApproval')) {
        return { 
          safe: false, 
          reason: 'Unlimited approval without ability to reset it' 
        };
      }
      return { safe: true, reason: 'Standard approval pattern' };
    }
  },
  {
    name: 'ERC721 Token Receiver',
    pattern: /(INonfungiblePositionManager|IERC721)/g,
    check: (code) => {
      if (!code.includes('onERC721Received')) {
        return { 
          safe: false, 
          reason: 'Contract interacts with ERC721 but does not implement onERC721Received' 
        };
      }
      return { safe: true, reason: 'Properly implements onERC721Received' };
    }
  }
];

function analyzeContract(contractPath) {
  console.log(`\n=== Security Analysis for ${path.basename(contractPath)} ===\n`);
  
  try {
    const code = fs.readFileSync(contractPath, 'utf8');
    let issuesFound = 0;
    
    for (const securityCheck of securityChecks) {
      console.log(`\nChecking for ${securityCheck.name} vulnerabilities:`);
      
      const matches = code.match(securityCheck.pattern);
      if (!matches) {
        console.log(`  ✅ No instances of ${securityCheck.name} pattern found`);
        continue;
      }
      
      let foundIssue = false;
      
      for (const match of matches) {
        const result = securityCheck.check(code, match);
        if (!result.safe) {
          console.log(`  ❌ ISSUE: ${result.reason}`);
          console.log(`     Related code: ${match.substring(0, 50)}...`);
          foundIssue = true;
          issuesFound++;
        }
      }
      
      if (!foundIssue) {
        console.log(`  ✅ ${matches.length} instances of ${securityCheck.name} pattern found, all secure`);
      }
    }
    
    console.log(`\n=== Summary for ${path.basename(contractPath)} ===`);
    if (issuesFound === 0) {
      console.log(`✅ No security issues detected`);
    } else {
      console.log(`❌ ${issuesFound} potential security issues detected`);
    }
  } catch (error) {
    console.error(`Error analyzing ${contractPath}: ${error.message}`);
  }
}

// Main function
function main() {
  console.log("DOVE Contract Security Analyzer");
  console.log("===============================");
  
  const contractsToAnalyze = [
    path.join(__dirname, '../../contracts/token/DOVEv3.sol'),
    path.join(__dirname, '../../contracts/liquidity/DOVELiquidityManager.sol')
  ];
  
  for (const contractPath of contractsToAnalyze) {
    analyzeContract(contractPath);
  }
}

main();
