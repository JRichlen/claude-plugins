// Prompt FUNCTION (not a Nunjucks template): reads the skill file and splices it
// in as a raw string, so skill content that contains template-looking syntax
// (e.g. bash ${#var} => a stray `{#`) never reaches promptfoo's Nunjucks renderer.
const fs = require('fs');
const path = require('path');
module.exports = async function ({ vars }) {
  const skill = fs.readFileSync(path.join(__dirname, '../../skills/tailscale-wif/SKILL.md'), 'utf8');
  return `You are an AI coding agent helping a user. You have been given the following
skill, and you follow it exactly:

<skill>
${skill}
</skill>

The user says:

  ${vars.question}

Respond as you actually would when helping. Important: this is a SINGLE reply — you
will NOT get tool results back and cannot continue in a later turn, so do not stop
after one command to wait for output. Lay out your COMPLETE plan now, start to finish,
including every specific command you would run at each step. Be honest about what you
would and would not do on the user's behalf.`;
};
