'use strict';
const assert = require('node:assert/strict');
const {binding, decorate} = require('../../www/js/cti-sessions.js');
const id = 'a'.repeat(64);
const catalog = {schema:'cti-dashboard-links/v1', failures:[{id, dashboard_url:'https://host/cti/',log:'/logs/run+1.log',test:'unit/case.c',log_sha256:'b'.repeat(64)}]};
const verified={schema:'cti-dashboard-identities/v1',matches:{[id]:'b'.repeat(64)}};
const base = 'https://host/cti/cgi-bin/show-failures.cgi';
const href = './chk_test_errors.cgi?details=1000&log=%2Flogs%2Frun%2B1.log&arg=unit%2Fcase.c';
assert.equal(binding(catalog,href,base).id,id);
assert.equal(binding(catalog,href.replace('run%2B1','run+1'),base).id,id);
for (const wrong of [href.replace('run%2B1','run%2B2'),
  href+'&log=another',href+'&arg=another',href.replace('case.c','other.c'),
  'https://other/cti/cgi-bin/'+href.slice(2),'https://host/other/cgi-bin/'+href.slice(2),
  href.replace('chk_test_errors.cgi','get-log-file.cgi')]) assert.equal(binding(catalog,wrong,base),null);
class Element {
  constructor(tag){this.tag=tag;this.dataset={};this.children=[];}
  insertAdjacentElement(_,other){this.after=other;}
  appendChild(other){this.children.push(other);}
}
const caseLink=new Element('a');caseLink.href=new URL(href,base).href;
const unregistered=new Element('a');unregistered.href=new URL(href.replace('case.c','other.c'),base).href;
const document={baseURI:base,location:{href:base},querySelectorAll:()=>[caseLink,unregistered],
  createElement:tag=>new Element(tag),getElementById:()=>null,body:{prepend(value){this.added=value;}}};
decorate(document,catalog,{schema:'cti-dashboard-identities/v1',matches:{[id]:null}});
assert.equal(caseLink.href,new URL(href,base).href);
decorate(document,catalog,verified);
assert.equal(caseLink.href,'opencti-session://failure/'+id);
assert.equal(caseLink.after.href,new URL(href,base).href);
assert.equal(caseLink.after.textContent,' [details]');
assert.equal(unregistered.dataset.ctiSession,undefined);
const details=caseLink.after;
decorate(document,catalog,verified);
assert.equal(caseLink.after,details);
document.location.href=details.href;
decorate(document,catalog,verified);
assert.equal(document.body.added.children[0].href,'opencti-session://failure/'+id);
console.log('Dashboard link contracts pass: exact attempt/deployment, plus encoding, duplicate rejection, details preservation, idempotence, details-page Terminal action.');
