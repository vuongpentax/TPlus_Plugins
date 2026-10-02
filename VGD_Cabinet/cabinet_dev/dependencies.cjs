const path=require('path');
const paths=[__dirname,path.resolve(__dirname,'../../TPlus_Cabinet_Codex_Handoff_2026-10-01/cabinet_dev')];
exports.resolve=name=>require.resolve(name,{paths});
exports.load=name=>require(exports.resolve(name));
