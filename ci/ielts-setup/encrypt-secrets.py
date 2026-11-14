"""Seal existing release configuration to this owner's IELTS repository key."""
import base64
import json
import os
from pathlib import Path
from nacl import encoding, public

box = public.SealedBox(public.PublicKey(os.environ['REPO_PUBLIC_KEY'].encode(), encoding.Base64Encoder()))
names = ['ASC_KEY_ID','ASC_ISSUER_ID','ASC_PRIVATE_KEY','MATCH_PASSWORD_NEXT','SIGNING_CERTIFICATE_ID','SIGNING_DEPLOY_KEY','SIGNING_STORE_URL']
encrypted = {}
for name in names:
    value = os.environ.get(name)
    if not value:
        raise SystemExit(f'Required existing release secret is missing: {name}')
    encrypted[name] = {'encrypted_value':base64.b64encode(box.encrypt(value.encode('utf-8'))).decode('ascii'),'key_id':os.environ['REPO_KEY_ID']}
output = Path('ielts-setup-output')
output.mkdir(exist_ok=True)
(output/'sealed-secrets.json').write_text(json.dumps(encrypted),encoding='utf-8')
print(f'Prepared {len(encrypted)} sealed values for Rookiei1/ielts-iphone. No plaintext credentials exported.')
