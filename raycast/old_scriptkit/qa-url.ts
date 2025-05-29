// Name: QA URL

import "@johnlindquist/kit"

const url = await getActiveTab('Arc' as any);

const newUrl = url.replace('app.hubspotqa.com', 'local.hubspotqa.com');

if (newUrl !== url) {
  await open(newUrl);
}



