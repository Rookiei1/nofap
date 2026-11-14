import crypto from 'node:crypto';
import fs from 'node:fs';

const bundleId = 'com.rookiei1.ieltspractice';
const header = Buffer.from(JSON.stringify({alg:'ES256', kid:process.env.ASC_KEY_ID, typ:'JWT'})).toString('base64url');
const issued = Math.floor(Date.now()/1000);
const claims = Buffer.from(JSON.stringify({iss:process.env.ASC_ISSUER_ID, iat:issued-30, exp:issued+600, aud:'appstoreconnect-v1'})).toString('base64url');
const signingInput = `${header}.${claims}`;
const signature = crypto.sign('sha256', Buffer.from(signingInput), {key:process.env.ASC_PRIVATE_KEY, dsaEncoding:'ieee-p1363'}).toString('base64url');
const token = `${signingInput}.${signature}`;
async function apple(path, method='GET', body) {
  const response = await fetch(`https://api.appstoreconnect.apple.com${path}`, {
    method, headers:{Authorization:`Bearer ${token}`, 'Content-Type':'application/json'},
    ...(body ? {body:JSON.stringify(body)} : {})
  });
  const value = await response.json();
  if (!response.ok) throw new Error(`Apple HTTP ${response.status}: ${(value.errors||[]).map(e=>e.code).join(',')}`);
  return value;
}
const report = {bundleId, name:'IELTS Practice', sku:'ielts-iphone-001', platform:'IOS', primaryLocale:'zh-Hans', checkedAt:new Date().toISOString()};
try {
  const [bundles, apps, certificate] = await Promise.all([
    apple(`/v1/bundleIds?filter[identifier]=${bundleId}`),
    apple(`/v1/apps?filter[bundleId]=${bundleId}`),
    apple(`/v1/certificates/${encodeURIComponent(process.env.SIGNING_CERTIFICATE_ID)}`)
  ]);
  const attrs = certificate.data.attributes;
  const cert = new crypto.X509Certificate(Buffer.from(attrs.certificateContent,'base64'));
  report.teamId = cert.subject.match(/(?:^|\n)OU=([^\n]+)/)?.[1] || null;
  report.existingCertificate = {type:attrs.certificateType, expires:attrs.expirationDate, valid:new Date(attrs.expirationDate)>new Date()};
  report.bundleRegistered = bundles.data.length > 0;
  report.appRecord = apps.data.length ? {id:apps.data[0].id, name:apps.data[0].attributes.name, primaryLocale:apps.data[0].attributes.primaryLocale} : null;
  if (!report.bundleRegistered && report.existingCertificate.valid) {
    const created = await apple('/v1/bundleIds','POST',{data:{type:'bundleIds',attributes:{name:'IELTS Practice',identifier:bundleId,platform:'IOS'}}});
    report.bundleRegistered = created.data.attributes.identifier === bundleId;
    report.bundleCreatedByThisSetup = report.bundleRegistered;
  }
  report.requiresAppRecord = !report.appRecord;
  report.readyForSigningPreflight = report.bundleRegistered && !!report.appRecord && report.existingCertificate.valid;
} catch (error) {
  report.error = String(error.message).slice(0,300);
  process.exitCode = 1;
} finally {
  fs.mkdirSync('ielts-setup-output',{recursive:true});
  fs.writeFileSync('ielts-setup-output/apple-preflight.json',JSON.stringify(report,null,2));
  const summary = `### IELTS account preflight\n\n\`\`\`json\n${JSON.stringify(report,null,2)}\n\`\`\`\n`;
  if (process.env.GITHUB_STEP_SUMMARY) fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY,summary);
  console.log(summary);
}
