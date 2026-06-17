#!/usr/bin/env node
/**
 * validate-skills.js
 *
 * skills/ 配下の各 skill を docs/skill-anatomy.md の規則に照らして検証する。
 *
 * Checks（errors は CI を block する）:
 *   - すべての skill directory に SKILL.md が存在する
 *   - YAML frontmatter に 'name' と 'description' fields がある
 *   - frontmatter 'name' が directory name と一致する
 *   - description が 1024 characters を超えない
 *   - required sections が存在する
 *
 * Checks（warnings は CI を block しない）:
 *   - cross-skill references が既知の skills を指している
 *
 * Exit codes: 0 = 問題なし、1 = 一つ以上の errors
 */

'use strict';

const fs   = require('fs');
const path = require('path');

// ─── 設定 ────────────────────────────────────────────────────────────────────

const SKILLS_DIR = path.resolve(__dirname, '..', 'skills');

const MAX_DESCRIPTION_LENGTH = 1024;

// standard SKILL.md が必ず持つ sections。
// 各 entry は許容 heading strings の配列。先にあるものを canonical として扱い、
// legacy aliases も並べられる。
const REQUIRED_SECTIONS = [
  ['## 概要', '## Overview'],
  ['## 使う場面', '## When to Use'],
  ['## よくある正当化', '## Common Rationalizations'],
  ['## 危険信号', '## Red Flags'],
  ['## 検証', '## Verification'],
];

// section checks から意図的に除外する skills。
// exemptions は skill frontmatter ではなくここに置く。contributors が自分の
// skill file を編集して validator を回避できないようにするため。
// すべての entry に reason を書くこと。
const SECTION_EXEMPT_SKILLS = {
  'using-agent-skills': 'メタスキル。ほかの skills を orchestrate する routing document なので、使う場面と検証の標準 section は適用しない。',
  'idea-refine':        'skill-anatomy.md より前の legacy structure。標準見出しの代わりに仕組み / 使い方 / anti-patterns を使う。conformance は https://github.com/addyosmani/agent-skills/issues で追跡する。',
};

// 明示的な cross-skill reference を示す regex patterns。
// dead-reference warning はこれらの patterns だけで出す。code blocks 内の
// generic backtick strings は意図的に除外する。
const SKILL_REF_PATTERNS = [
  /\buse the `([a-z][a-z0-9-]+[a-z0-9])` skill/g,
  /\bfollow the `([a-z][a-z0-9-]+[a-z0-9])` skill/g,
  /\binvoke the `([a-z][a-z0-9-]+[a-z0-9])` skill/g,
  /\bcontinue with `([a-z][a-z0-9-]+[a-z0-9])`/g,
  /\buse `([a-z][a-z0-9-]+[a-z0-9])` skill/g,
  /`([a-z][a-z0-9-]+[a-z0-9])` skill\b/g,
  /`([a-z][a-z0-9-]+[a-z0-9])` persona\b/g,
  /\bsee `([a-z][a-z0-9-]+[a-z0-9])`/g,
  /──→ ([a-z][a-z0-9-]+[a-z0-9])\b/g,          // ASCII diagram arrows
  /`([a-z][a-z0-9-]+[a-z0-9])` を使う/g,
  /`([a-z][a-z0-9-]+[a-z0-9])` に渡す/g,
];

// ─── ヘルパー ────────────────────────────────────────────────────────────────

/**
 * markdown file の先頭から YAML-style frontmatter を parse する。
 * key→value object を返す。frontmatter block がなければ null。
 * values から surrounding quotes を取り除く。
 */
function parseFrontmatter(content) {
  const match = content.match(/^---[ \t]*\r?\n([\s\S]*?)\r?\n---[ \t]*\r?\n/);
  if (!match) return null;

  const result = {};
  for (const line of match[1].split(/\r?\n/)) {
    const colonIdx = line.indexOf(':');
    if (colonIdx === -1) continue;
    const key   = line.slice(0, colonIdx).trim();
    const value = line.slice(colonIdx + 1).trim().replace(/^['"]|['"]$/g, '');
    if (key) result[key] = value;
  }
  return result;
}

/**
 * content から明示的な skill cross-references を収集する。
 * inline code snippets による false positives を避けるため、
 * SKILL_REF_PATTERNS list だけに match させる。
 */
function extractSkillReferences(content) {
  const refs = new Set();
  for (const pattern of SKILL_REF_PATTERNS) {
    // global regexes の lastIndex を reset する
    pattern.lastIndex = 0;
    let m;
    while ((m = pattern.exec(content)) !== null) {
      refs.add(m[1]);
    }
  }
  return refs;
}

// ─── Validator ───────────────────────────────────────────────────────────────

function validateSkill(dirName, knownSkills) {
  const errors   = [];
  const warnings = [];
  let   exempt   = false;
  const skillPath = path.join(SKILLS_DIR, dirName, 'SKILL.md');

  if (!fs.existsSync(skillPath)) {
    errors.push('SKILL.md がありません');
    return { errors, warnings, exempt };
  }

  let content;
  try {
    content = fs.readFileSync(skillPath, 'utf8');
  } catch (err) {
    errors.push(`SKILL.md を読めません: ${err.message}`);
    return { errors, warnings, exempt };
  }

  // ── Frontmatter ──────────────────────────────────────────────────────────
  const fm = parseFrontmatter(content);
  if (!fm) {
    errors.push('YAML frontmatter がない、または壊れています（file 先頭に --- block が必要）');
    return { errors, warnings, exempt };
  }

  if (!fm.name) {
    errors.push("Frontmatter に required field 'name' がありません");
  } else if (fm.name !== dirName) {
    errors.push(`Frontmatter name '${fm.name}' が directory name '${dirName}' と一致しません`);
  }

  if (!fm.description) {
    errors.push("Frontmatter に required field 'description' がありません");
  } else if (fm.description.length > MAX_DESCRIPTION_LENGTH) {
    errors.push(
      `Description は ${fm.description.length} chars です。${MAX_DESCRIPTION_LENGTH}-char limit を超えています` +
      `（agents はこれを system prompt に inject します）`
    );
  }

  // ── Exemption guard ──────────────────────────────────────────────────────
  // exemptions は validator-owned（上の SECTION_EXEMPT_SKILLS）。
  // skill frontmatter が自分の exemption を宣言しようとしたら loud に fail する。
  // validator を bypass しようとしている sign だから。
  if (fm.type === 'meta' || fm.exempt === 'sections') {
    if (!SECTION_EXEMPT_SKILLS[dirName]) {
      errors.push(
        `Frontmatter が 'type: meta' または 'exempt: sections' を宣言していますが、'${dirName}' は ` +
        `validator の SECTION_EXEMPT_SKILLS allowlist にありません。` +
        `理由を添えて scripts/validate-skills.js に entry を追加してください。`
      );
    }
  }

  // ── Required sections ────────────────────────────────────────────────────
  exempt = dirName in SECTION_EXEMPT_SKILLS;

  if (!exempt) {
    for (const aliases of REQUIRED_SECTIONS) {
      const found = aliases.some(heading => content.includes(heading));
      if (!found) {
        errors.push(`required section がありません: ${aliases[0]}`);
      }
    }
  }

  // ── Cross-skill references ───────────────────────────────────────────────
  const refs = extractSkillReferences(content);
  for (const ref of refs) {
    if (!knownSkills.has(ref)) {
      warnings.push(`dead cross-reference: \`${ref}\` は既知の skill ではありません`);
    }
  }

  return { errors, warnings, exempt };
}

// ─── Main ────────────────────────────────────────────────────────────────────

function main() {
  if (!fs.existsSync(SKILLS_DIR)) {
    console.error(`エラー: skills directory が見つかりません: ${SKILLS_DIR}`);
    process.exit(1);
  }

  const skillDirs = fs.readdirSync(SKILLS_DIR)
    .filter(d => fs.statSync(path.join(SKILLS_DIR, d)).isDirectory())
    .sort();

  const knownSkills = new Set(skillDirs);

  let totalErrors   = 0;
  let totalWarnings = 0;

  for (const dirName of skillDirs) {
    const { errors, warnings, exempt } = validateSkill(dirName, knownSkills);
    totalErrors   += errors.length;
    totalWarnings += warnings.length;

    if (errors.length === 0 && warnings.length === 0) {
      const tag = exempt ? '（section checks exempt）' : '';
      console.log(`  ✓  ${dirName}${tag}`);
    } else {
      const icon = errors.length > 0 ? '  ✗ ' : '  ⚠ ';
      console.log(`${icon} ${dirName}`);
      for (const msg of errors)   console.log(`       エラー: ${msg}`);
      for (const msg of warnings) console.log(`       警告:   ${msg}`);
    }
  }

  const status = totalErrors > 0 ? '失敗' : totalWarnings > 0 ? '警告付きで成功' : '成功';
  console.log(`\n${skillDirs.length} skills を確認 — ${totalErrors} エラー, ${totalWarnings} 警告 — ${status}`);

  if (totalErrors > 0) process.exit(1);
}

// unexpected failures（fs errors、bad symlinks など）は uncaught stack trace ではなく、
// structured one-line CI error として出す。
try {
  main();
} catch (err) {
  console.error(`\nエラー: validate-skills が予期せず失敗しました: ${err.message}`);
  process.exit(1);
}
