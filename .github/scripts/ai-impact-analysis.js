const https = require('https');
const fs = require('fs');

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

function sendSlack(risk, summary, changedFiles, callback) {
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
    risk === 'MEDIUM' ? 'MEDIUM RISK - REVIEW' :
    'LOW RISK - DEPLOYING';

  const statusText =
    risk === 'HIGH'
      ? '*HIGH risk — deployment BLOCKED. Do not deploy until resolved.*'
      : risk === 'MEDIUM'
      ? '*MEDIUM risk — manual review required before deploying.*'
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
  // 1) Best possible parse: explicit machine-readable line
  const finalRiskMatch = analysis.match(/FINAL_RISK\s*=\s*(HIGH|MEDIUM|LOW)/i);
  if (finalRiskMatch && finalRiskMatch[1]) {
    return finalRiskMatch[1].toUpperCase();
  }

  // 2) Strong structured patterns only
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

  // 3) Fail-safe: if AI explicitly says do not deploy, treat as HIGH
  if (/DO NOT DEPLOY/i.test(analysis)) {
    return 'HIGH';
  }

  // 4) Final fail-safe: block on uncertainty
  return 'HIGH';
}

const codeContext = readChangedFiles(CHANGED_FILES);

const orgContext =
  'Evaluate only what is present in the changed code. ' +
  'Rate LOW if: pure utility/helper methods, no SOQL, no DML, no HTTP callouts, no Salesforce object references. ' +
  'Rate MEDIUM if: touches Salesforce objects but is bulkified and follows best practices. ' +
  'Rate HIGH if: SOQL/DML/callouts inside loops, hardcoded IDs, no error handling on queries. ' +
  'Do NOT elevate risk based on hypothetical callers or assumed automation.';

const prompt =
  'You are a senior Salesforce architect reviewing code changes before deployment.\n\n' +
  'Analyze the following changed Apex files and provide:\n' +
  '1. Impacted Components - List Triggers, Flows, Objects, Fields affected\n' +
  '2. Deployment Risks - Specific risks in a Salesforce org\n' +
  '3. Recommended Tests - Test scenarios to validate\n' +
  '4. Risk Level - Score as LOW, MEDIUM, or HIGH with reason\n\n' +
  'IMPORTANT: End your response with exactly one final line in this exact format:\n' +
  'FINAL_RISK=HIGH\n' +
  'or\n' +
  'FINAL_RISK=MEDIUM\n' +
  'or\n' +
  'FINAL_RISK=LOW\n\n' +
  'Do not include any extra text after FINAL_RISK.\n\n' +
  'Changed files:\n' + codeContext + '\n\n' +
  'Org context: ' + orgContext + '\n\n' +
  'Be specific and concise.';

const payload = JSON.stringify({
  model: 'claude-sonnet-4-5',
  max_tokens: 1200,
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

        // Fail safe: if AI call fails, block deployment
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

      sendSlack(risk, analysis, CHANGED_FILES, () => {
        if (risk === 'HIGH') {
          console.log('HIGH risk detected - deployment should be blocked by workflow conditions.');
        } else if (risk === 'MEDIUM') {
          console.log('MEDIUM risk detected - manual review should be required.');
        } else {
          console.log('LOW risk detected - deployment may proceed.');
        }

        // Always exit 0 so the workflow can use outputs cleanly
        process.exit(0);
      });

    } catch (e) {
      console.error('Parse error:', e.message);

      // Fail safe: if parsing fails, block deployment
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

  // Fail safe: if API request fails, block deployment
  const ghOutput = process.env.GITHUB_OUTPUT;
  if (ghOutput) {
    fs.appendFileSync(ghOutput, 'risk=HIGH\n');
  }

  process.exit(0);
});

req.write(payload);
req.end();