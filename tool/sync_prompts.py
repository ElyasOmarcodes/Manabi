"""Regenerates app/lib/core/pipeline/prompt_texts.dart from server/src/prompts.mjs.

Run from the repository root: python3 tool/sync_prompts.py
CI fails if the generated file is out of date.
"""
import re, sys
src = open('server/src/prompts.mjs').read()
def tpl(name):
    return re.search(r'export const ' + name + r' = `(.*?)`;', src, re.S).group(1)
def dart_raw(s):
    assert "'''" not in s
    return s.replace('\\', '\\\\').replace('$', '\\$')
compose = re.search(r'export const composeSystem = \(languageName\) => `(.*?)`;', src, re.S).group(1)
out = f"""// GENERATED from server/src/prompts.mjs by tool/sync_prompts.py – do not edit by hand.
// ignore_for_file: prefer_single_quotes

const planSystem = '''{dart_raw(tpl('PLAN_SYSTEM'))}''';

const rerankSystem = '''{dart_raw(tpl('RERANK_SYSTEM'))}''';

String composeSystem(String languageName) => '''{dart_raw(compose).replace('\\${languageName}', '$languageName')}''';

const layersSystem = '''{dart_raw(tpl('LAYERS_SYSTEM'))}''';
"""
path = 'app/lib/core/pipeline/prompt_texts.dart'
if '--check' in sys.argv:
    sys.exit(0 if open(path).read() == out else 'prompt_texts.dart is out of date: run python3 tool/sync_prompts.py')
open(path, 'w').write(out)
