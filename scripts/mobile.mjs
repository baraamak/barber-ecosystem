import { mkdir, copyFile, readFile, writeFile } from 'node:fs/promises';
import { build } from 'esbuild';
await mkdir('www', { recursive: true });
await build({stdin: { contents: "export {createClient} from '@supabase/supabase-js'",resolveDir: process.cwd()},bundle:true, format:'esm', minify:true, outfile:'www/supabase.js'});
for (const file of ['auth.html', 'index.html']) {
  const source = await readFile(file, 'utf8');
  const bundled = source.replaceAll('https://esm.sh/@supabase/supabase-js@2.49.1','./supabase.js');
  await writeFile('www/'+file, process.argv.includes('--web') ? bundled : bundled.replace("new URL('./auth.html',location.href).href","'https://baraamak.github.io/barber-ecosystem/auth.html'"));
}
for (const file of ['role-workspace.js','theme.css','manifest.webmanifest','sw.js']) await copyFile(file, 'www/'+file);
