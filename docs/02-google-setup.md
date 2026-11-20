# 02 — Google setup

Every build of Hollow uses a Google OAuth client that the builder creates. Nothing in this
repository contains a client ID or secret. The steps take about 10 minutes and cost nothing.

## Steps

1. In [Google Cloud Console](https://console.cloud.google.com), create a project, for example `Hollow`.
2. **APIs & Services → Library**: enable **Google Drive API**.
3. **Google Auth Platform → Get started**: app name `Hollow`, your support email, contact email.
   For **Audience**, choose **External**.
4. **Audience → Test users → Add users**: add every Google account that will sign in while the app
   is in testing (up to 100).
5. **Data access → Add or remove scopes**: add only
   `https://www.googleapis.com/auth/drive.file`. It appears under non-sensitive scopes. Do not add
   broader Drive scopes; they require a security assessment.
6. **Clients → Create client → Desktop app**. Download the JSON immediately: Google shows the secret
   only at creation. If you lose it, open the client and use **Add secret**, then download again.
7. Build with it:
   ```bash
   ./scripts/build-app.sh ~/Downloads/client_secret_XXXX.json
   ```
   The first line of output reads `using Google client XXXX…`.

## Errors and what they mean

| What you see | Cause | Fix |
| --- | --- | --- |
| `Error 403: org_internal` | Audience is **Internal**, and the account is not in that Workspace organisation | **Audience → Make external** |
| `Error 403: access_denied` | App is in testing and the account is not a test user | Add the account under **Test users** |
| "Google hasn't verified this app" | Normal while in testing | Choose **Continue** |
| Consent screen says "rclone" | The build has no client of its own | Rebuild with your client JSON |
| `invalid_client` | The build used a placeholder secret | The build script now refuses these; rebuild with the real JSON |
| Logo missing on the consent screen | Logos appear only after brand verification | Expected until the app is published and verified |

## Letting anyone sign in

Testing allows up to 100 test users over the app's lifetime. To open sign-in to everyone:

1. Own a domain and verify it in Google Search Console.
2. Publish a homepage and a privacy policy on that domain. For Drive data, the policy MUST state how
   Google user data is used, that it is used only to show and store the user's files, and that it is
   not sold or shared (Google's Limited Use requirements).
3. Fill in **Branding**: logo (`branding/google-consent-logo.png`, 120 × 120), homepage, privacy
   policy, authorised domain.
4. **Audience → Publish app**. With a logo, Google reviews the branding, which usually takes a few
   business days **[verify]** against Google's current published timeline.
