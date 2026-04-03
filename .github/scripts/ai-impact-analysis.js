const https = require('https');
const fs = require('fs');
const { execSync } = require('child_process');

const ANTHROPIC_KEY = process.env.ANTHROPIC_API_KEY;
const SLACK_WEBHOOK = process.env.SLACK_WEBHOOK_URL;
const CHANGED_FILES = process.env.CHANGED_FILES || '';
const REPO = process.env.GITHUB_REPOSITORY || 'unknown/repo';
const COMMIT = process.env.GITHUB_SHA ? process.env.GITHUB_SHA.substring(0, 7) : 'unknown';
const ACTOR = process.env.GITHUB_ACTOR || 'unknown';

if (!CHANGED_FILES) {
  console.log('No Apex files changed. Skipping AI analysis.');
  process.exit(0);
}

function readChangedFiles(fileList) {
  return fileList.split(',')
    .filter(f => f.trim() && fs.existsSync(f.trim()))
    .map(f => {
      const content = fs.readFileSync(f.trim(), 'utf8');
      return 'File: ' + f.trim() + '\n' + content;
    }).join('\n\n');
}

function detectImpactedObjects(codeContext) {
  const objectNames = [
    'Case', 'Account', 'Contact', 'Lead', 'Opportunity', 'Task',
    'Event', 'User', 'Profile', 'Group'
  ];

  const detected = new Set();

  for (const obj of objectNames) {
    const regex = new RegExp('\\b' + obj + '\\b', 'g');
    if (regex.test(codeContext)) {
      detected.add(obj);
    }
  }

  return Array.from(detected);
}

function runSfQuery(soql) {
  try {
    const output = execSync(`sf data query --query "${soql.replace(/"/g, '\\"')}" --json`, {
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'pipe']
    });

    const parsed = JSON.parse(output);
    return parsed.result?.records || [];
  } catch (e) {
    console.log('SF query failed:', soql);
    return [];
  }
}

function getDependencyContext(objects) {
  const context = {
    triggers: [],
    validationRules: [],
    flows: [],
    assignmentRules: []
  };

  for (const obj of objects) {
    if (obj === 'Case' || obj === 'Account' || obj === 'Contact' || obj === 'Lead' || obj === 'Opportunity') {
      const triggers = runSfQuery(
        `SELECT Name, TableEnumOrId, Status FROM ApexTrigger WHERE TableEnumOrId = '${obj}'`
      );

      context.triggers.push(...triggers.map(t => ({
        object: obj,
        name: t.Name,
        status: t.Status
      })));

      const rules = runSfQuery(
        `SELECT Id, ValidationName, EntityDefinition.QualifiedApiName, Active FROM ValidationRule WHERE EntityDefinition.QualifiedApiName = '${obj}'`
      );

      context.validationRules.push(...rules.map(r => ({
        object: obj,
        name: r.ValidationName,
        active: r.Active
      })));

      const flows = runSfQuery(
        `SELECT DeveloperName, MasterLabel, Status FROM Flow WHERE ProcessType = 'Flow'`
      );

      context.flows.push(...flows.map(f => ({
        object: obj,
        name: f.MasterLabel || f.DeveloperName,
        status: f.Status
      })));

      if (obj === 'Case' || obj === 'Lead') {
        const assignmentRules = runSfQuery(
          `SELECT Name, SObjectType, Active FROM AssignmentRule WHERE SObjectType = '${obj}'`
        );

        context.assignmentRules.push(...assignmentRules.map(r => ({
          object: obj,
          name: r.Name,
          active: r.Active
        })));
      }
    }
  }

  return context;
}

function formatDependencyContext(dep) {
  let text = '';

  text += 'Detected Org Dependencies:\n\n';

  text += 'Triggers:\n';
  if (dep.triggers.length) {
    dep.triggers.forEach(t => {
      text += `- ${t.name} (${t.object}, Status: ${t.status})\n`;
    });
  } else {
    text += '- None found\n';
  }

  text += '\nValidation Rules:\n';
  if (dep.validationRules.length) {
    dep.validationRules.forEach(v => {
      text += `- ${v.name} (${v.object}, Active: ${v.active})\n`;
    });
  } else {
    text += '- None found\n';
  }

  text += '\nFlows:\n';
  if (dep.flows.length) {
    dep.flows.forEach(f => {
      text += `- ${f.name} (${f.object}, Status: ${f.status})\n`;
    });
  } else {
    text += '- None found\n';
  }

  text += '\nAssignment Rules:\n';
  if (dep.assignmentRules.length) {
    dep.assignmentRules.forEach(a => {
      text += `- ${a.name} (${a.object}, Active: ${a.active})\n`;
    });
  } else {
    text += '- None found\n';
  }

  return text;
}

function sendSlack(risk, summary, changedFiles, dependencySummary, callback) {
  if (!SLACK_WEBHOOK) {
    console.log('No Slack webhook, skipping.');
    callback();
    return;
  }

  const color =
    risk === 'HIGH' ? '#DC2626' :
    risk === 'MEDIUM' ? '#F59E0B' :
    '#16A34A';

  const riskLabel =
    risk === 'HIGH' ? 'HIGH RISK - BLOCKED' :
    risk === 'MEDIUM' ? 'MEDIUM RISK - DEPLOYING WITH WARNING' :
    'LOW RISK - DEPLOYING';

  const statusText =
    risk === 'HIGH'
      ? '*HIGH risk — deployment BLOCKED. Do not deploy until resolved.*'
      : risk === 'MEDIUM'
      ? '*MEDIUM risk — deployment allowed with warning. Review recommended.*'
      : '*LOW risk — auto-deploying to Salesforce org now.*';

  const message = {
    attachments: [{
      color: color,
      blocks: [
        {
          type: 'header',
          text: {
            type: 'plain_text',
            text: 'Predictive DevOps — AI Impact Analysis',
            emoji: true
          }
        },
        {
          type: 'section',
          fields: [
            { type: 'mrkdwn', text: '*Repository:*\n' + REPO },
            { type: 'mrkdwn', text: '*Commit:*\n`' + COMMIT + '`' },
            { type: 'mrkdwn', text: '*Pushed by:*\n' + ACTOR },
            { type: 'mrkdwn', text: '*Risk Level:*\n*' + riskLabel + '*' }
          ]
        },
        { type: 'divider' },
        {
          type: 'section',
          text: {
            type: 'mrkdwn',
            text: '*Changed files:*\n`' + changedFiles + '`'
          }
        },
        {
          type: 'section',
          text: {
            type: 'mrkdwn',
            text: '*Dependency Warning Summary:*\n' + dependencySummary.substring(0, 2500)
          }
        },
        {
          type: 'section',
          text: {
            type: 'mrkdwn',
            text: '*Claude Analysis:*\n' + summary.substring(0, 2500)
          }
        },
        { type: 'divider' },
        {
          type: 'section',
          text: {
            type: 'mrkdwn',
            text: statusText
          }
        }
      ]
    }]
  };

  const payload = JSON.stringify(message);
  const url = new URL(SLACK_WEBHOOK);

  const options = {
    hostname: url.hostname,
    path: url.pathname,
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(payload)
    }
  };

  const req = https.request(options, (res) => {
    console.log('Slack notification sent. Status: ' + res.statusCode);
    callback();
  });

  req.on('error', (e) => {
    console.error('Slack failed:', e.message);
    callback();
  });

  req.write(payload);
  req.end();
}

function extractRisk(analysis) {
  const finalRiskMatch = analysis.match(/FINAL_RISK\s*=\s*(HIGH|MEDIUM|LOW)/i);
  if (finalRiskMatch && finalRiskMatch[1]) {
    return finalRiskMatch[1].toUpperCase();
  }

  const riskPatterns = [
    /\*\*RISK:\s*(HIGH|MEDIUM|LOW)\*\*/i,
    /\bRISK:\s*(HIGH|MEDIUM|LOW)\b/i,
    /\bRisk Level:\s*(HIGH|MEDIUM|LOW)\b/i,
    /\bRisk Assessment:\s*(HIGH|MEDIUM|LOW)\b/i,
    /\bOverall Risk:\s*(HIGH|MEDIUM|LOW)\b/i
  ];

  for (const pattern of riskPatterns) {
    const match = analysis.match(pattern);
    if (match && match[1]) {
      return match[1].toUpperCase();
    }
  }

  if (/DO NOT DEPLOY/i.test(analysis)) {
    return 'HIGH';
  }

  return 'HIGH';
}

const codeContext = readChangedFiles(CHANGED_FILES);
const impactedObjects = detectImpactedObjects(codeContext);
const dependencyContext = getDependencyContext(impactedObjects);
const dependencyText = formatDependencyContext(dependencyContext);

console.log('\n============================================================');
console.log('   DEPENDENCY CONTEXT');
console.log('============================================================');
console.log(dependencyText);
console.log('============================================================\n');

const orgContext =
  'Evaluate only what is present in the changed code plus the provided dependency metadata. ' +
  'Use a realistic Salesforce deployment risk lens, not an overly strict academic one. ' +
  'LOW risk if the code is bulkified, has no SOQL/DML in loops, no hardcoded IDs, no obviously unsafe comments, and uses standard predictable Salesforce patterns even if it includes SOQL or DML. ' +
  'MEDIUM risk if the code has configuration dependency (queues, profiles, labels, custom metadata), direct DML without advanced error handling, or assumptions that may vary by org but is still generally well-structured and safe. ' +
  'HIGH risk only if the code has SOQL/DML/callouts inside loops, hardcoded IDs, unsafe or misleading comments, non-bulkified logic, obvious production-danger patterns, or clearly untested / reckless deployment behavior. ' +
  'Do NOT elevate risk just because Case triggers, flows, assignment rules, or org automation might exist. Only assess actual dependency metadata provided. ' +
  'Do NOT mark code HIGH just because it updates Salesforce records. Standard CRUD/DML is normal and acceptable if implemented safely.';

const prompt =
  'You are a senior Salesforce architect reviewing code changes before deployment.\n\n' +
  'Analyze the following changed Apex files and org dependency metadata.\n\n' +
  'Provide:\n' +
  '1. Impacted Components - Include actual dependent component names from metadata where relevant\n' +
  '2. Possible Impact - Explain what may break or behave differently because of this code change\n' +
  '3. Deployment Risks - Specific risks in this Salesforce org\n' +
  '4. Recommended Tests - Test scenarios to validate\n' +
  '5. Risk Level - Score as LOW, MEDIUM, or HIGH with reason\n\n' +
  'IMPORTANT RISK CALIBRATION:\n' +
  '- LOW = production-safe, conventional Salesforce code with standard DML/SOQL usage and no major red flags\n' +
  '- MEDIUM = acceptable but has config dependency, portability assumptions, or moderate maintainability concerns\n' +
  '- HIGH = dangerous / error-prone / obviously unsafe / should not auto-deploy\n\n' +
  'IMPORTANT: If dependency metadata contains named triggers, validation rules, flows, or assignment rules, explicitly list them by name and explain the possible impact of this code on them.\n\n' +
  'IMPORTANT: End your response with exactly one final line in this exact format:\n' +
  'FINAL_RISK=HIGH\n' +
  'or\n' +
  'FINAL_RISK=MEDIUM\n' +
  'or\n' +
  'FINAL_RISK=LOW\n\n' +
  'Do not include any extra text after FINAL_RISK.\n\n' +
  'Changed files:\n' + codeContext + '\n\n' +
  'Dependency metadata:\n' + dependencyText + '\n\n' +
  'Org context: ' + orgContext + '\n\n' +
  'Be specific and concise.';

const payload = JSON.stringify({
  model: 'claude-sonnet-4-5',
  max_tokens: 1500,
  messages: [{ role: 'user', content: prompt }]
});

const options = {
  hostname: 'api.anthropic.com',
  path: '/v1/messages',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'x-api-key': ANTHROPIC_KEY,
    'anthropic-version': '2023-06-01',
    'Content-Length': Buffer.byteLength(payload)
  }
};

const req = https.request(options, (res) => {
  let data = '';

  res.on('data', chunk => data += chunk);

  res.on('end', () => {
    try {
      const json = JSON.parse(data);

      if (json.error) {
        console.error('Claude API error:', json.error.message);

        const ghOutput = process.env.GITHUB_OUTPUT;
        if (ghOutput) {
          fs.appendFileSync(ghOutput, 'risk=HIGH\n');
        }

        process.exit(0);
      }

      const analysis = json.content[0].text;
      const risk = extractRisk(analysis);

      console.log('\n============================================================');
      console.log('   AI IMPACT ANALYSIS - Predictive DevOps (Claude)');
      console.log('============================================================');
      console.log('\nChanged files: ' + CHANGED_FILES + '\n');
      console.log(analysis);
      console.log('\n============================================================');

      console.log('\nRisk assessment: ' + risk);

      const ghOutput = process.env.GITHUB_OUTPUT;
      if (ghOutput) {
        fs.appendFileSync(ghOutput, 'risk=' + risk + '\n');
      }

      console.log('Risk written to GitHub output: ' + risk);

      sendSlack(risk, analysis, CHANGED_FILES, dependencyText, () => {
        if (risk === 'HIGH') {
          console.log('HIGH risk detected - deployment should be blocked by workflow conditions.');
        } else if (risk === 'MEDIUM') {
          console.log('MEDIUM risk detected - deployment allowed with warning.');
        } else {
          console.log('LOW risk detected - deployment may proceed.');
        }

        process.exit(0);
      });

    } catch (e) {
      console.error('Parse error:', e.message);

      const ghOutput = process.env.GITHUB_OUTPUT;
      if (ghOutput) {
        fs.appendFileSync(ghOutput, 'risk=HIGH\n');
      }

      process.exit(0);
    }
  });
});

req.on('error', (e) => {
  console.error('Request failed:', e.message);

  const ghOutput = process.env.GITHUB_OUTPUT;
  if (ghOutput) {
    fs.appendFileSync(ghOutput, 'risk=HIGH\n');
  }

  process.exit(0);
});

req.write(payload);
req.end();