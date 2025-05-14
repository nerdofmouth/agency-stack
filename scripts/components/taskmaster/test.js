#!/usr/bin/env node

/**
 * Taskmaster-AI MCP Server Test Script
 * 
 * This script tests the taskmaster-ai MCP server functionality
 * following AgencyStack principles of repository integrity and proper testing.
 * 
 * Usage: node test.js
 */

const path = require('path');
const { spawn } = require('child_process');
const fs = require('fs');

// Log directory setup
const logDir = '/var/log/agency_stack/components';
if (!fs.existsSync(logDir)) {
  console.log(`Creating log directory: ${logDir}`);
  try {
    fs.mkdirSync(logDir, { recursive: true });
  } catch (err) {
    console.warn(`Warning: Could not create log directory: ${err.message}`);
  }
}

const logFile = path.join(logDir, 'taskmaster-ai.log');

// Test function
async function testTaskmasterAi() {
  console.log('Testing Taskmaster-AI MCP server...');
  
  try {
    // Use npx to run the task-master-ai directly
    const taskmaster = spawn('npx', [
      '-y', 
      '--package=task-master-ai', 
      'task-master-ai',
      '--test'
    ], {
      env: {
        ...process.env,
        ANTHROPIC_API_KEY: "REMOVED_SECRET",
        PERPLEXITY_API_KEY: "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",
        OPENAI_API_KEY: "REMOVED_SECRET",
        GOOGLE_API_KEY: "AIzaSyDLQzZ76JuU7cm0Fj2fRk-uqtGAb8iQH9c"
      }
    });

    // Set timeout to avoid hanging indefinitely
    const timeout = setTimeout(() => {
      console.log('Test timeout after 10 seconds');
      taskmaster.kill();
    }, 10000);
    
    // Handle output
    taskmaster.stdout.on('data', (data) => {
      const output = data.toString();
      console.log(`[STDOUT]: ${output}`);
      try {
        fs.appendFileSync(logFile, `[${new Date().toISOString()}] [STDOUT] ${output}\n`);
      } catch (err) {
        console.warn(`Could not write to log: ${err.message}`);
      }
    });

    taskmaster.stderr.on('data', (data) => {
      const error = data.toString();
      console.error(`[STDERR]: ${error}`);
      try {
        fs.appendFileSync(logFile, `[${new Date().toISOString()}] [STDERR] ${error}\n`);
      } catch (err) {
        console.warn(`Could not write to log: ${err.message}`);
      }
    });

    // Handle exit
    taskmaster.on('close', (code) => {
      clearTimeout(timeout);
      console.log(`Child process exited with code ${code}`);
      try {
        fs.appendFileSync(logFile, `[${new Date().toISOString()}] Process exited with code ${code}\n`);
      } catch (err) {
        console.warn(`Could not write to log: ${err.message}`);
      }
    });

    // Give command input after a short delay
    setTimeout(() => {
      if (taskmaster.stdin.writable) {
        taskmaster.stdin.write(JSON.stringify({
          jsonrpc: "2.0",
          method: "ping",
          params: {},
          id: 1
        }) + '\n');
      }
    }, 1000);

  } catch (error) {
    console.error(`Error executing taskmaster-ai: ${error.message}`);
    try {
      fs.appendFileSync(logFile, `[${new Date().toISOString()}] Error: ${error.message}\n`);
    } catch (err) {
      console.warn(`Could not write to log: ${err.message}`);
    }
  }
}

// Execute the test
testTaskmasterAi();
