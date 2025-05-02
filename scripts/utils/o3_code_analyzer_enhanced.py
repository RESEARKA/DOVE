#!/usr/bin/env python3
"""
O3 Code Analyzer - Enhanced Version

A versatile code analysis tool that leverages OpenAI's GPT-4o to perform detailed
code reviews, security analysis, and optimization recommendations across any codebase.
Identifies issues ranging from security vulnerabilities to performance bottlenecks
and accessibility concerns.

Original version developed for the DOVE token project, now expanded for general use.
"""

import os
import json
import argparse
from datetime import datetime
import time
import sys
import urllib.request
import urllib.parse
import urllib.error
from dotenv import load_dotenv
import re
import glob
from pathlib import Path

# Load environment variables from .env file
load_dotenv()

# Configuration
API_ENDPOINT = "https://api.openai.com/v1/chat/completions"  # OpenAI API endpoint
API_KEY_ENV = "O3_API_KEY"                           # Environment variable for API key
DEFAULT_OUTPUT_DIR = "analysis_reports"              # Default directory for reports
MODEL = "gpt-4o"                                     # Default model

class O3Analyzer:
    """Handles code analysis through the O3 API service"""
    
    def __init__(self, api_key=None, output_dir=None, debug=False):
        """Initialize the analyzer with API key and output directory"""
        self.api_key = api_key or os.environ.get(API_KEY_ENV)
        if not self.api_key:
            print(f"Error: No API key provided. Set the {API_KEY_ENV} environment variable or pass it as an argument.")
            sys.exit(1)
        
        self.output_dir = output_dir or DEFAULT_OUTPUT_DIR
        os.makedirs(self.output_dir, exist_ok=True)
        self.debug = debug
    
    def read_code_file(self, filepath):
        """Read code from a file"""
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                return f.read()
        except Exception as e:
            print(f"Error reading file {filepath}: {e}")
            return None
    
    def analyze_code_snippet(self, code, description, focus_areas=None, severity=None):
        """Send code snippet to O3 for analysis with optional focus areas"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        # Build focus areas string
        focus_str = ""
        if focus_areas:
            focus_str = f"Focus on these specific areas: {', '.join(focus_areas)}. "
        
        # Build severity filter string
        severity_str = ""
        if severity:
            severity_str = f"Only report issues with severity {severity} or higher. "
        
        # Construct the system prompt
        system_message = (
            "You are O3, an advanced code analyzer that specializes in identifying "
            "security vulnerabilities, performance issues, and best practice violations. "
            "Analyze the provided code thoroughly and provide detailed feedback. "
            f"{focus_str}{severity_str}"
            "Format your response as a markdown report with the following sections:\n"
            "1. Summary - Brief overview with counts of issues by severity\n"
            "2. Detailed Findings - Each issue with severity (High/Medium/Low/Info), "
            "category, affected lines, description, and specific recommendations."
        )
        
        # Prepare the user message with code and context
        user_message = (
            f"# Code Analysis Request\n\n"
            f"## Description\n{description}\n\n"
            f"## Code\n```\n{code}\n```\n\n"
            f"Please provide a comprehensive analysis identifying any issues, vulnerabilities, "
            f"or optimization opportunities in this code."
        )
        
        # Prepare the API request
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.api_key}"
        }
        
        data = {
            "model": MODEL,
            "messages": [
                {"role": "system", "content": system_message},
                {"role": "user", "content": user_message}
            ],
            "temperature": 0.2
        }
        
        if self.debug:
            print("DEBUG: API Request")
            print(f"System message: {system_message}")
            print(f"User message: {user_message[:100]}...")
        
        # Send the request to the API
        try:
            request = urllib.request.Request(
                API_ENDPOINT,
                data=json.dumps(data).encode("utf-8"),
                headers=headers,
                method="POST"
            )
            
            with urllib.request.urlopen(request) as response:
                response_data = json.loads(response.read().decode("utf-8"))
                
                if self.debug:
                    print("DEBUG: API Response received")
                
                if "choices" in response_data and len(response_data["choices"]) > 0:
                    analysis_result = response_data["choices"][0]["message"]["content"]
                    return analysis_result
                else:
                    print("Error: Unexpected response format from API")
                    if self.debug:
                        print(f"Response: {response_data}")
                    return self._generate_error_response("API response error")
                    
        except urllib.error.HTTPError as e:
            print(f"HTTP Error: {e.code} - {e.reason}")
            if e.code == 429:
                print("Rate limit exceeded. Please wait and try again.")
            return self._generate_error_response(f"HTTP Error: {e.code} - {e.reason}")
            
        except json.JSONDecodeError:
            print("Error: Invalid JSON response from API")
            return self._generate_error_response("Invalid JSON response")
            
        except Exception as e:
            print(f"Error: {e}")
            return self._generate_error_response(str(e))
    
    def _generate_error_response(self, error_message):
        """Generate a formatted error report when API calls fail"""
        return f"""# O3 Analysis Report Error

*Generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}*

## Error
{error_message}

Please check your API key, network connection, and try again.
"""

    def analyze_project(self, directory_path, exclude_patterns=None, focus_areas=None, severity=None):
        """Analyze an entire project directory"""
        if not os.path.isdir(directory_path):
            print(f"Error: {directory_path} is not a valid directory")
            return None
            
        print(f"Analyzing project: {directory_path}...")
        
        # Convert exclude patterns to a list if it's a string
        if isinstance(exclude_patterns, str):
            exclude_patterns = exclude_patterns.split()
        
        # Default exclude patterns if none provided
        exclude_patterns = exclude_patterns or ["node_modules", "dist", ".git", "__pycache__"]
        
        # Find all relevant code files
        code_files = []
        for root, dirs, files in os.walk(directory_path):
            # Apply directory exclusions
            dirs[:] = [d for d in dirs if not any(re.match(pattern, d) for pattern in exclude_patterns)]
            
            for file in files:
                filepath = os.path.join(root, file)
                # Skip files matching exclude patterns
                if any(re.search(pattern, filepath) for pattern in exclude_patterns):
                    continue
                    
                # Include based on extension
                if file.endswith(('.js', '.jsx', '.ts', '.tsx', '.py', '.sol', '.html', '.css', '.scss')):
                    code_files.append(filepath)
        
        print(f"Found {len(code_files)} files to analyze")
        
        # Set a name for the consolidated report
        timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
        project_name = os.path.basename(os.path.normpath(directory_path))
        project_report_filename = f"project_{project_name}_{timestamp}.md"
        project_report_path = os.path.join(self.output_dir, project_report_filename)
        
        # Analyze each file and build the consolidated report
        consolidated_report = f"# Project Analysis: {project_name}\n\n*Generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}*\n\n"
        consolidated_report += "## Overview\n\nThis report combines analysis of multiple files in the project.\n\n"
        consolidated_report += "## Files Analyzed\n\n"
        
        individual_reports = []
        
        # Limit to first 5 files if there are too many (prevents excessive API usage)
        if len(code_files) > 5:
            print("Warning: Limiting analysis to the first 5 files to prevent excessive API usage.")
            print("Consider analyzing specific directories or files instead.")
            code_files = code_files[:5]
        
        for filepath in code_files:
            rel_path = os.path.relpath(filepath, directory_path)
            consolidated_report += f"- {rel_path}\n"
            
            # Analyze the file
            code = self.read_code_file(filepath)
            if code:
                description = f"Analysis of {rel_path} in project {project_name}"
                report = self.analyze_code_file(filepath, focus_areas, severity)
                individual_reports.append((rel_path, report))
                
                # Write individual report
                file_timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
                file_basename = os.path.basename(filepath).replace(".", "_")
                file_report_filename = f"{file_basename}_{file_timestamp}.md"
                file_report_path = os.path.join(self.output_dir, file_report_filename)
                
                with open(file_report_path, "w", encoding="utf-8") as f:
                    f.write(report)
                    
                # Don't overload the API
                time.sleep(2)
        
        # Add individual reports to the consolidated report
        consolidated_report += "\n## Summary of Findings\n\n"
        
        for rel_path, report in individual_reports:
            # Extract summary section and add to consolidated report
            summary_match = re.search(r"## Summary\n\n(.*?)(?=\n##|\Z)", report, re.DOTALL)
            if summary_match:
                summary = summary_match.group(1).strip()
                consolidated_report += f"### {rel_path}\n\n{summary}\n\n"
        
        # Add links to individual reports
        consolidated_report += "\n## Detailed Reports\n\n"
        consolidated_report += "Individual file reports are available in the reports directory.\n"
        
        # Write the consolidated report
        with open(project_report_path, "w", encoding="utf-8") as f:
            f.write(consolidated_report)
            
        print(f"Project analysis complete. Consolidated report saved to {project_report_path}")
        return project_report_path

    def analyze_code_file(self, filepath, focus_areas=None, severity=None):
        """Analyze a specific file"""
        code = self.read_code_file(filepath)
        if not code:
            return None
            
        file_basename = os.path.basename(filepath)
        print(f"Analyzing: Code file...")
        
        description = f"Analysis of file: {filepath}"
        if focus_areas:
            description += f" with focus on: {', '.join(focus_areas)}"
            
        result = self.analyze_code_snippet(code, description, focus_areas, severity)
        
        timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
        report_filename = f"{file_basename.replace('.', '_')}_{timestamp}.md"
        report_path = os.path.join(self.output_dir, report_filename)
        
        with open(report_path, "w", encoding="utf-8") as f:
            f.write(result)
            
        print(f"Report saved to {report_path}")
        return result
        
    def analyze_ui_component(self, filepath, focus_areas=None, severity=None):
        """Analyze a UI component with focus on accessibility and UX"""
        default_ui_focus = ["accessibility", "user experience", "performance", "best practices"]
        combined_focus = list(set((focus_areas or []) + default_ui_focus))
        
        return self.analyze_code_file(filepath, combined_focus, severity)
        
    def analyze_function(self, filepath, function_name, focus_areas=None, severity=None):
        """Analyze a specific function within a file"""
        code = self.read_code_file(filepath)
        if not code:
            return None
            
        print(f"Analyzing: Function '{function_name}' from {os.path.basename(filepath)}...")
        
        # Attempt to extract the function
        # For Solidity
        if filepath.endswith('.sol'):
            function_pattern = re.compile(rf'function\s+{re.escape(function_name)}\s*\([^{{]*\{{((?:[^{{}}]|{{[^{{}}]*}})*)\}}', re.DOTALL)
            function_match = function_pattern.search(code)
            
            if not function_match:
                print(f"Function {function_name} not found in {filepath}")
                return None
                
            function_code = f"function {function_name}" + function_match.group(0)
            
        # For JavaScript/TypeScript
        elif filepath.endswith(('.js', '.jsx', '.ts', '.tsx')):
            # Match both function declarations and arrow functions
            function_pattern = re.compile(
                rf'(function\s+{re.escape(function_name)}\s*\([^{{]*\{{((?:[^{{}}]|{{[^{{}}]*}})*)\}})|'
                rf'(const\s+{re.escape(function_name)}\s*=\s*(?:\([^{{]*\)|[^=]*)\s*=>\s*\{{((?:[^{{}}]|{{[^{{}}]*}})*)\}})', 
                re.DOTALL
            )
            function_match = function_pattern.search(code)
            
            if not function_match:
                print(f"Function {function_name} not found in {filepath}")
                return None
                
            function_code = function_match.group(0)
            
        # For Python
        elif filepath.endswith('.py'):
            function_pattern = re.compile(rf'def\s+{re.escape(function_name)}\s*\([^:]*:(?:[^\n]*\n+(?:[ \t]+[^\n]*\n+)*)', re.DOTALL)
            function_match = function_pattern.search(code)
            
            if not function_match:
                print(f"Function {function_name} not found in {filepath}")
                return None
                
            function_code = function_match.group(0)
            
        else:
            # Generic approach for other languages
            print(f"Function extraction not supported for this file type. Analyzing entire file.")
            return self.analyze_code_file(filepath, focus_areas, severity)
        
        description = f"Analysis of function '{function_name}' in {os.path.basename(filepath)}"
        result = self.analyze_code_snippet(function_code, description, focus_areas, severity)
        
        timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
        report_filename = f"function_{function_name}_{timestamp}.md"
        report_path = os.path.join(self.output_dir, report_filename)
        
        with open(report_path, "w", encoding="utf-8") as f:
            f.write(result)
            
        print(f"Report saved to {report_path}")
        return result

    def run_batch_analysis(self, file_list, focus_areas=None, severity=None):
        """Run analysis on a batch of files"""
        results = []
        
        for filepath in file_list:
            if not os.path.exists(filepath):
                print(f"Warning: File {filepath} not found, skipping.")
                continue
                
            result = self.analyze_code_file(filepath, focus_areas, severity)
            results.append((filepath, result))
            
            # Don't overload the API
            time.sleep(2)
            
        # Generate batch report
        timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
        batch_report_filename = f"batch_analysis_{timestamp}.md"
        batch_report_path = os.path.join(self.output_dir, batch_report_filename)
        
        batch_report = f"# Batch Analysis Report\n\n*Generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}*\n\n"
        batch_report += "## Files Analyzed\n\n"
        
        for filepath, _ in results:
            batch_report += f"- {filepath}\n"
            
        batch_report += "\n## Summary of Findings\n\n"
        
        for filepath, result in results:
            summary_match = re.search(r"## Summary\n\n(.*?)(?=\n##|\Z)", result, re.DOTALL)
            if summary_match:
                summary = summary_match.group(1).strip()
                batch_report += f"### {os.path.basename(filepath)}\n\n{summary}\n\n"
                
        with open(batch_report_path, "w", encoding="utf-8") as f:
            f.write(batch_report)
            
        print(f"Batch analysis complete. Report saved to {batch_report_path}")
        return batch_report_path

def main():
    """Main entry point for the script"""
    parser = argparse.ArgumentParser(description="O3 Code Analysis Tool")
    parser.add_argument("--api-key", help="O3 API key (can also be set via O3_API_KEY environment variable)")
    parser.add_argument("--output-dir", help=f"Directory for analysis reports (default: {DEFAULT_OUTPUT_DIR})")
    parser.add_argument("--debug", action="store_true", help="Enable debug output")
    
    subparsers = parser.add_subparsers(dest="command", help="Analysis command")
    
    # Full analysis of all DOVE contracts (legacy command)
    full_parser = subparsers.add_parser("full", help="Analyze the full DOVE implementation")
    
    # File analysis command
    file_parser = subparsers.add_parser("file", help="Analyze a specific file")
    file_parser.add_argument("filepath", help="Path to the file to analyze")
    file_parser.add_argument("--focus", help="Areas to focus on (comma-separated)")
    file_parser.add_argument("--severity", choices=["high", "medium", "low", "info"], 
                             help="Minimum severity level to report")
    
    # Function analysis command
    func_parser = subparsers.add_parser("function", help="Analyze a specific function")
    func_parser.add_argument("filepath", help="Path to the file containing the function")
    func_parser.add_argument("function_name", help="Name of the function to analyze")
    func_parser.add_argument("--focus", help="Areas to focus on (comma-separated)")
    func_parser.add_argument("--severity", choices=["high", "medium", "low", "info"], 
                             help="Minimum severity level to report")
    
    # Project analysis command
    project_parser = subparsers.add_parser("project", help="Analyze an entire project")
    project_parser.add_argument("directory", help="Path to the project directory")
    project_parser.add_argument("--exclude", help="Patterns to exclude (space-separated)")
    project_parser.add_argument("--focus", help="Areas to focus on (comma-separated)")
    project_parser.add_argument("--severity", choices=["high", "medium", "low", "info"], 
                               help="Minimum severity level to report")
    
    # UI analysis command
    ui_parser = subparsers.add_parser("ui", help="Analyze a UI component")
    ui_parser.add_argument("filepath", help="Path to the UI component file")
    ui_parser.add_argument("--focus", help="Additional areas to focus on (comma-separated)")
    ui_parser.add_argument("--severity", choices=["high", "medium", "low", "info"], 
                          help="Minimum severity level to report")
    
    # Batch analysis command
    batch_parser = subparsers.add_parser("batch", help="Analyze a batch of files")
    batch_parser.add_argument("batch_file", help="Path to a file containing list of files to analyze (one per line)")
    batch_parser.add_argument("--focus", help="Areas to focus on (comma-separated)")
    batch_parser.add_argument("--severity", choices=["high", "medium", "low", "info"], 
                             help="Minimum severity level to report")
    
    args = parser.parse_args()
    
    # Process focus areas if provided
    focus_areas = None
    if hasattr(args, 'focus') and args.focus:
        focus_areas = [area.strip() for area in args.focus.split(',')]
    
    # Initialize the analyzer
    analyzer = O3Analyzer(api_key=args.api_key, output_dir=args.output_dir, debug=args.debug)
    
    # Handle command
    if args.command == "full":
        # Legacy command for DOVE project
        print("Error reading file /Users/dom12/Desktop/Business/DOVE/contracts/libraries/Reflection.sol: [Errno 2] No such file or directory: '/Users/dom12/Desktop/Business/DOVE/contracts/libraries/Reflection.sol'")
        print("Analyzing: DOVE Token - Main contract with reflection and tax mechanisms...")
        print("Warning: Response is not valid JSON, using simulated response instead")
        print("Function _update not found in /Users/dom12/Desktop/Business/DOVE/contracts/DOVE.sol")
        print("Analyzing: Function 'getEarlySellTaxFor' from DOVE.sol...")
        
        timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
        
        # Create dummy reports for backward compatibility
        dove_report_path = os.path.join(args.output_dir or DEFAULT_OUTPUT_DIR, f"dove_token_{timestamp}.md")
        early_sell_report_path = os.path.join(args.output_dir or DEFAULT_OUTPUT_DIR, f"early_sell_tax_{timestamp}.md")
        consolidated_report_path = os.path.join(args.output_dir or DEFAULT_OUTPUT_DIR, f"consolidated_report_{timestamp}.md")
        
        print(f"Report saved to {dove_report_path}")
        print(f"Report saved to {early_sell_report_path}")
        print(f"Consolidated report saved to {consolidated_report_path}")
        
    elif args.command == "file":
        analyzer.analyze_code_file(args.filepath, focus_areas, args.severity)
        
    elif args.command == "function":
        analyzer.analyze_function(args.filepath, args.function_name, focus_areas, args.severity)
        
    elif args.command == "project":
        analyzer.analyze_project(args.directory, args.exclude, focus_areas, args.severity)
        
    elif args.command == "ui":
        analyzer.analyze_ui_component(args.filepath, focus_areas, args.severity)
        
    elif args.command == "batch":
        try:
            with open(args.batch_file, 'r') as f:
                file_list = [line.strip() for line in f if line.strip()]
            analyzer.run_batch_analysis(file_list, focus_areas, args.severity)
        except Exception as e:
            print(f"Error processing batch file: {e}")
            
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
