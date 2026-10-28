# Week 4 Lab — Cryptography: Hashing Passwords and Enforcing HTTPS

**Lecture:** Introduction to Cryptography; Public Key Cryptography and PKI

---

## Overview

In Week 2 you captured credentials in cleartext and stole a session cookie over an unencrypted connection. This week you fix both of those problems. You will replace plaintext password storage with bcrypt hashing, configure HTTPS using a self-signed certificate, and verify each remediation by re-running the Week 2 attacks and documenting the difference in outcome.

---

## Tools

| Tool | Purpose |
|------|---------|
| bcrypt (Python library) | Hash and verify passwords |
| OpenSSL | Generate a self-signed TLS certificate |
| Wireshark | Verify HTTPS traffic is no longer readable |
| MySQL CLI | Inspect the database before and after hashing |
| nginx config files | Enable HTTPS on the web server |
| Docker Compose | Rebuild and redeploy |

### Platform Notes

**OpenSSL:**
- **macOS:** Pre-installed. Verify with `openssl version` in Terminal.
- **Linux:** Pre-installed on most distributions. Install with `sudo apt install openssl` if missing.
- **Windows:** OpenSSL is included with **Git for Windows**. Open Git Bash and verify with `openssl version`. If not present, download the installer from [slproweb.com/products/Win32OpenSSL.html](https://slproweb.com/products/Win32OpenSSL.html).

**MySQL CLI:**
- The MySQL client runs inside the Docker container — no local installation is needed. All MySQL commands in this lab use `docker exec` to connect to the container.

**Docker commands** work identically across all platforms in Terminal (macOS/Linux) or Git Bash / PowerShell (Windows).

---

## Steps

Run terminal commands from your existing `huskyhub` folder. Continue with your Week 2 observations and keep the Week 3 AI fixes. When a step opens the MySQL prompt, type `exit;` to return to your terminal before running Docker or OpenSSL commands.

### 1. Observe Plaintext Passwords in the Database

**What `docker exec` does and why we use it here:**
`docker exec` runs a command inside an already-running container. The `-it` flags combine `-i` (keep stdin open) and `-t` (allocate a terminal), which together give you an interactive shell session inside the container. We use this because the MySQL server is running inside the Docker container's isolated network — we use the bundled client so you do not need to install MySQL tools on your laptop. The command `mysql -u user -psupersecretpw huskyhub` connects to MySQL as the `user` account and immediately selects the `huskyhub` database.

Connect to the running MySQL container:

```bash
docker exec -it huskyhub-db mysql -u user -psupersecretpw huskyhub
```

Run:
```sql
SELECT username, password FROM users;
```

Screenshot the output. This is the before state.

---

### 2. Add bcrypt to the Application

**Why a dedicated password hashing library and not a general-purpose hash:**
General-purpose hash functions like SHA-256 or MD5 are designed to be fast — they can compute billions of hashes per second on commodity hardware. This is exactly wrong for passwords: a fast hash makes it trivial to try every word in a dictionary or every possible 8-character combination (a brute force attack) in hours. bcrypt is designed to be deliberately slow and to allow its cost factor to be increased as hardware gets faster. It also automatically generates a unique random salt for each password, which means two users with the same password will have completely different hash outputs — a precomputed table of hashes (a rainbow table) is therefore useless against a properly bcrypt-hashed database.

In `flask/requirements.txt`, add:
```
bcrypt==4.1.2
```

Rebuild to confirm it installs:
```bash
docker compose up --build -d
```

---

### 3. Write a Password Hashing Utility

**What each function call in this utility does:**
`plaintext.encode()` converts the Python string to bytes, because bcrypt operates on raw bytes rather than text strings. `bcrypt.gensalt()` generates a cryptographically random salt value — by default this encodes a cost factor of 12, meaning the hash computation iterates 2^12 = 4096 times. `bcrypt.hashpw(plaintext, salt)` runs the bcrypt algorithm and returns a single string that contains the salt, the cost factor, and the resulting hash all concatenated together. This is why bcrypt does not need a separate salt column in the database — the salt is embedded in the hash itself. `checkpw` performs the same computation on the plaintext and compares — it never stores or returns the plaintext.

Create a new file `flask/app/utils.py`:

```python
import bcrypt

def hash_password(plaintext: str) -> str:
    return bcrypt.hashpw(plaintext.encode(), bcrypt.gensalt()).decode()

def check_password(plaintext: str, hashed: str) -> bool:
    return bcrypt.checkpw(plaintext.encode(), hashed.encode())
```

---

### 4. Write a Migration Script

**What a migration script is and why you cannot simply re-hash in place:**
A migration script is a one-time program that transforms existing data from one format to another. You cannot simply overwrite passwords with their hashes in a single SQL UPDATE because you need to read each plaintext value, compute its hash, and write the result back — a row-by-row operation. After this script runs, the plaintext values no longer exist in the database. The script should be idempotent where possible (safe to run more than once), and after running it you should immediately verify the output before proceeding — a migration error that silently corrupts passwords would lock every user out of their account.

Create `flask/migrate_passwords.py`. This script should:
1. Connect to the database
2. Read every user record
3. Skip any password already beginning with `$2b$` or `$2a$` (so the script is safe to run more than once)
4. Hash each plaintext password using your utility function
5. Update the record with the hash

Use `get_connection()` from `app.database` and `hash_password()` from `app.utils`, identify each record by `user_id`, and commit the updates before closing the connection.

The Dockerfile copies `flask/app/` and the provided tests into the image, but a one-time script placed at `flask/migrate_passwords.py` is **not** included. Rebuild first so your new `utils.py` is in the image, then copy the migration script into the running container and execute it:

```bash
docker compose up --build -d
docker cp flask/migrate_passwords.py huskyhub-flask:/app/migrate_passwords.py
docker exec -it huskyhub-flask python migrate_passwords.py
```

Verify in MySQL that no plaintext passwords remain. Run the script a second time and confirm the stored hashes do not change. Login will not work with the migrated accounts until you complete Step 5. If a later rebuild recreates the Flask container, copy the script into it again before rerunning it.

---

### 5. Update the Login Endpoint

**Why the SQL query must change — not just the comparison:**
The starter's login query includes both the submitted username and plaintext password. After hashing, the database contains bcrypt strings like `$2b$12$...`, not plaintext. You cannot compare a plaintext password to a bcrypt hash in SQL — the comparison must happen in Python using `check_password()`. Retrieve the approved user by username, then verify the submitted password against that user's stored hash.

Make the following edits in `flask/app/routes/auth.py`. Each example shows the surrounding existing code; comments marked **ADD** or **CHANGED** identify the new lines. Keep SQL parameterization as the Week 8 exercise.

**5.1. Add the password utility import.** At the top of the file, add this line immediately after the existing database import:

```python
from flask import (
    Blueprint, request, redirect, url_for,
    render_template, make_response
)
from ..database import get_connection
from ..utils import hash_password, check_password  # ADD

auth_bp = Blueprint("auth", __name__)
```

**5.2. Remove the password comparison from the login query.** Inside `login()`, replace the existing query block with the one below. The `AND password = ...` line is removed; keep `AND approved = 1` so unapproved accounts cannot log in. Leave the following execute, fetch, and close lines in place:

```python
        # Retrieve the approved account; check its password in Python below.
        query = (
            f"SELECT * FROM users "
            f"WHERE username = '{username}' "
            f"AND approved = 1"
        )
        cursor.execute(query)
        user = cursor.fetchone()
        conn.close()
```

**5.3. Verify the password and use the retrieved identity.** Immediately below `conn.close()`, replace the existing login success/failure block with this version. Change `if user:` to the password check shown below, and change the `authenticated` cookie value from `username` to `user["username"]`:

```python
        user = cursor.fetchone()
        conn.close()

        if user and check_password(password, user["password"]):  # CHANGED
            resp = make_response(redirect(url_for("home")))
            # Store identity in cookies so the app knows who is logged in
            resp.set_cookie("authenticated", user["username"])  # CHANGED
            resp.set_cookie("role", user["role"])
            resp.set_cookie("user_id", str(user["user_id"]))
            return resp
        else:
            error = "Invalid username or password."
```

The first two lines are existing context: keep only one copy of them. The `user and` check prevents an unknown username from reaching `check_password()`. Leave the final `return render_template("login.html", error=error)` and the logout route unchanged.

Rebuild after editing `auth.py`:

```bash
docker compose up --build -d
```

Test that an approved existing account can still log in after the migration. Verify that a wrong password, an unknown username, and the unapproved `pending1` account are rejected without a server error.

---

### 6. Update the Registration Endpoint

Continue editing the same `flask/app/routes/auth.py` file. The `hash_password` import was added in Step 5.1.

**6.1. Hash the submitted password before building the INSERT.** Inside `register()`, add `hashed = hash_password(password)` immediately after the `email` line and before `conn = get_connection()`:

```python
        username = request.form.get("username", "")
        password = request.form.get("password", "")
        first_name = request.form.get("first_name", "")
        last_name = request.form.get("last_name", "")
        email = request.form.get("email", "")

        hashed = hash_password(password)  # ADD

        conn = get_connection()
        cursor = conn.cursor()
```

**6.2. Insert the hash instead of the plaintext password.** In the query directly below those lines, replace `{password}` with `{hashed}` in the VALUES string:

```python
        cursor = conn.cursor()

        query = (
            f"INSERT INTO users "
            f"(username, first_name, last_name, email, password, role, approved) "
            f"VALUES ('{username}', '{first_name}', '{last_name}', "
            f"'{email}', '{hashed}', 'student', 0)"  # CHANGED
        )
```

The `cursor` line is existing context; keep only one copy. The assignment in Step 6.1 must appear before this query uses `hashed`. Keep the role as `'student'` and `approved` as `0`, and retain the existing `try`/`except`/`finally` block, including `conn.commit()`.

Rebuild after saving both registration changes:

```bash
docker compose up --build -d
```

Verify registration and approval:

1. Open `/register` in your browser and create an account with an unused username, such as `crypto_test`.
2. Open the MySQL prompt using the command in Step 1. Run this query, replacing `crypto_test` if you chose a different username:

   ```sql
   SELECT username, password, approved FROM users WHERE username = 'crypto_test';
   ```

   Confirm the stored password begins with `$2b$12$` and `approved` is `0`. Type `exit;` to leave MySQL.
3. Try logging in as the new account. Login must be rejected before approval.
4. Log in as `admin`, open **Users** (`/admin/users`), and click **Approve** for your new account. Log out, then confirm the new account can log in with its original password.
5. Confirm a wrong password is still rejected and `pending1` still cannot log in. Approve only your new test account; leave `pending1` unapproved.

---

### 7. Generate a Self-Signed TLS Certificate

**What each flag in the OpenSSL command does:**
`req -x509` generates a self-signed certificate (skipping the Certificate Signing Request step normally used when a CA is involved). `-newkey rsa:4096` creates a new RSA private key with a 4096-bit key length at the same time. `-keyout` and `-out` specify where to save the private key and certificate respectively. `-days 365` sets the certificate to expire in one year. `-nodes` (from "no DES") means the private key is saved without password encryption — necessary because nginx needs to read it automatically at startup without prompting. `-subj` provides the certificate's subject fields inline so OpenSSL does not prompt interactively; `CN=localhost` sets the display name. Modern browsers validate the **Subject Alternative Name (SAN)**; the command below includes `DNS:localhost` for the URL used in this lab.

**macOS / Linux:**
```bash
openssl req -x509 -newkey rsa:4096 \
  -keyout nginx/key.pem \
  -out nginx/cert.pem \
  -days 365 -nodes \
  -subj "/C=US/ST=Washington/O=UW/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
```

**Windows (Git Bash):** use the same command with Git Bash path conversion disabled for the certificate subject:

```bash
MSYS_NO_PATHCONV=1 openssl req -x509 -newkey rsa:4096 \
  -keyout nginx/key.pem \
  -out nginx/cert.pem \
  -days 365 -nodes \
  -subj "/C=US/ST=Washington/O=UW/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
```

Verify `openssl version` first. If the installed OpenSSL/LibreSSL lacks `-addext`, use the provided [localhost certificate config](../../nginx/openssl-localhost.cnf.example) instead; this also avoids Git Bash's subject-string conversion:

```bash
openssl req -x509 -newkey rsa:4096 -nodes -days 365 \
  -keyout nginx/key.pem -out nginx/cert.pem \
  -config nginx/openssl-localhost.cnf.example
```

Both methods include a localhost SAN. Keep nginx/key.pem private and out of submissions. Inspect the resulting certificate with `openssl x509 -in nginx/cert.pem -noout -text`; confirm the names and dates before mounting it.

This generates a private key and a self-signed certificate in the `nginx/` directory.

---

### 8. Configure nginx for HTTPS

**What the nginx configuration changes accomplish at the network level:**
The first server block listens on port 80 (HTTP) and immediately issues an HTTP 301 redirect to the HTTPS version of the same URL. This means any client that connects over plain HTTP is immediately instructed to reconnect over HTTPS — subsequent requests use HTTPS; a client that initially POSTs a password to HTTP has already sent that body before receiving a redirect, so use the HTTPS login URL directly. The second block listens on port 443 (HTTPS), loads the certificate and private key, and proxies requests to the Flask container. `ssl_certificate` contains the public certificate sent to clients; `ssl_certificate_key` contains the private key used to authenticate the server during the TLS handshake. The private key never leaves the server. `proxy_set_header X-Real-IP` passes the client's original IP address to Flask, which nginx would otherwise mask behind its own internal IP.

Update `nginx/default.conf` to add an SSL server block on port 443 and redirect port 80 traffic to it:

```nginx
server {
    listen 80;
    server_name localhost;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name localhost;

    ssl_certificate     /etc/nginx/certs/cert.pem;
    ssl_certificate_key /etc/nginx/certs/key.pem;

    # Keep serving static files directly, as in the original config
    location /static/ {
        alias /var/www/html/static/;
    }

    location / {
        proxy_pass http://huskyhub-flask:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

> Keep the `location /static/` block inside the new `443` server block (it was present in the original `nginx/default.conf`) so nginx continues serving CSS and other static assets directly.

Update the existing `huskyhub-nginx` service in `docker-compose.yaml` to mount the certs and expose port 443. **Add** the following entries to its existing ports/volumes; retain the static-file mount and other settings:
```yaml
huskyhub-nginx:
  ports:
    - "80:80"
    - "443:443"
  volumes:
    - ./nginx/default.conf:/etc/nginx/conf.d/default.conf
    - ./nginx/cert.pem:/etc/nginx/certs/cert.pem
    - ./nginx/key.pem:/etc/nginx/certs/key.pem
    - ./flask/app/static:/var/www/html/static
```

Apply the configuration and check nginx:

```bash
docker compose up --build -d
docker compose exec huskyhub-nginx nginx -t
```

Navigate directly to `https://localhost/login`. Accept the browser certificate warning (this is expected for self-signed certificates — your browser has not been configured to trust a Certificate Authority that signed this certificate). Confirm login and static styling still work. Separately open `http://localhost` and confirm it redirects to HTTPS.

---

### 9. Re-run the Week 2 Wireshark Capture

**What TLS does to the packet contents Wireshark sees:**
TLS (Transport Layer Security) encrypts the entire HTTP payload between the client and the server using a symmetric key negotiated during the TLS handshake. Wireshark can still capture the packets, but it sees only the encrypted ciphertext — it cannot recover the HTTP headers, the POST body, or the session cookies from those packets without the negotiated traffic secrets (a modern forward-secret TLS capture is not decrypted merely by obtaining the server private key). This is what "encryption in transit" means: the data is present on the wire, but it is computationally infeasible to read without the key.

With Wireshark capturing, log in over `https://localhost`. Capture on the loopback interface for this localhost connection, using `tcp.port == 443` (or `tls`) as the display filter. Locate the handshake and encrypted application-data records. The Week 2 filter `http.request.method == "POST"` should no longer expose the login on this connection; an empty HTTP filter alone is not proof that a capture worked. Show both that TLS traffic was captured and that username/password/cookie headers are not readable in its payload. Do not enable TLS key logging for this exercise.

> **macOS note:** To capture `localhost` HTTPS traffic in Wireshark, select the **Loopback (lo0)** interface.

> **Windows note:** Select the **Npcap Loopback Adapter** interface.

---

### 10. Verify the Database Remediation

Run the same MySQL query from Step 1:
```sql
SELECT username, password FROM users;
```

Screenshot the output. All values should now be bcrypt hashes beginning with `$2b$12$`.

---

## Write-Up Questions

**Q1.** Explain the difference between encryption and hashing. Why is hashing the correct approach for password storage rather than symmetric encryption?

**Q2.** What is a salt in the context of bcrypt? Paste one hash from your database and identify which part of the string is the salt. Why does bcrypt embed the salt in the hash output rather than storing it separately?

**Q3.** Your certificate is self-signed. What is the difference between a self-signed certificate and one signed by a Certificate Authority? What specific attack does a CA signature protect against that your certificate does not?

---

## Hacker Mindset Prompt

Cryptography is frequently implemented incorrectly not because developers are ignorant of it, but because they make wrong assumptions about what it guarantees. MD5 and SHA-1 are cryptographic hash functions and yet they are completely inappropriate for password storage.

Reflect on:

- **Contrarian:** Why is a fast hash function (like SHA-256) *worse* for passwords than a slow one (like bcrypt)? What attacker behavior does this speed difference enable?
- **Committed:** If an attacker obtained a database full of bcrypt hashes, describe the exact process they would use to attempt to crack them. What resources would they need?
- **Creative:** bcrypt was designed in 1999. What properties would you want in a password hashing algorithm designed today, and does bcrypt still meet them?

---

## Optional Extension — Local Certificate Trust (Extra Credit)

Earn **0.5 extra-credit points added to your lab score** by completing this extension and answering **both extra-credit write-up questions** below. Complete the instructions for **one operating system** and verify trust in your browser. Include your verification evidence and answers in an extra-credit subsection of your lab's **Write-Up Questions** section. This extension does not replace the required HTTPS verification in Step 9.

### 1. Install and Trust the Certificate — Choose Your OS

Use the public certificate, `nginx/cert.pem`, that you generated in Step 7. Perform these steps on the computer running your browser, outside Docker. For a Windows browser, use the Windows certificate store even if you generated the certificate in WSL. Keep `nginx/key.pem` private.

#### macOS — Keychain Access

1. Press **Cmd+Space**, type **Keychain Access**, and press **Return**.
2. In the left sidebar, select **login** to trust the certificate for your account, or **System** to make it available system-wide.
3. In Finder, open your `huskyhub/nginx` folder and drag **cert.pem** into the selected keychain in Keychain Access. Enter administrator credentials if prompted.
4. Select the **Certificates** category or tab, find the certificate named **localhost**, and double-click it. Check its details against the certificate you generated if you have several localhost entries, then expand **Trust**.
5. Set **Secure Sockets Layer (SSL)** to **Always Trust**.
6. Close the certificate window and authenticate if prompted to save the change. Fully quit and reopen your browser, then continue to **Verify Browser Trust** below.

[Apple: add certificates](https://support.apple.com/en-ie/guide/keychain-access/kyca2431/mac) · [Apple: change certificate trust](https://support.apple.com/en-ie/guide/keychain-access/kyca11871/mac)

#### Windows — Local Computer Certificate Store

1. In Git Bash, from your `huskyhub` folder, create a Windows-friendly copy of the public certificate:

   ```bash
   openssl x509 -in nginx/cert.pem -outform der -out nginx/cert.cer
   ```

2. Press **Win+R**, type **certlm.msc**, and press **Enter**. Approve the administrator prompt if shown. This opens **Certificates — Local Computer**; importing here requires administrator permission.
3. Expand **Trusted Root Certification Authorities**, then select **Certificates**.
4. Right-click **Certificates** and choose **All Tasks → Import…**. Click **Next**, then **Browse…**.
5. Navigate to your `huskyhub/nginx` folder, select **cert.cer**, and click **Open**, then **Next**.
6. Confirm **Place all certificates in the following store** is selected and the store is **Trusted Root Certification Authorities**. Click **Next → Finish**. Confirm the installation if prompted, then click **OK** on the success message.
7. Find **localhost** in the certificate list and open it to check its details. Continue to **Verify Browser Trust** below.

[Microsoft: certificate-store scopes and imports](https://learn.microsoft.com/en-us/windows-server/identity/ad-cs/inspect-certificates-manage-certificate-stores)

#### Ubuntu / Debian — System Trust Store

1. Open a terminal on your Linux host and change to your `huskyhub` folder.
2. Copy the public certificate into the local trust directory with a `.crt` extension, then update the trust store:

   ```bash
   sudo cp nginx/cert.pem /usr/local/share/ca-certificates/huskyhub.crt
   sudo update-ca-certificates
   ```

3. Check the command output for the added certificate. Continue below; some Linux browsers, especially sandboxed packages, also need a browser-specific import.

[Ubuntu: install a certificate in the trust store](https://ubuntu.com/server/docs/how-to/security/install-a-root-ca-certificate-in-the-trust-store/)

### 2. Verify Browser Trust

1. Fully quit and reopen your browser, then visit **https://localhost**.
2. Confirm the site opens without a certificate warning or clicking through an exception. Open the browser's site-information or connection-security control beside the address bar, then view the certificate. The icon and labels vary by browser; a padlock is not required.
3. Check that the certificate is the one you installed, includes **localhost** in its Subject Alternative Names, and is within its validity dates. Capture the trusted certificate entry in your OS certificate manager and the browser's warning-free connection/certificate details for your report.

**If Firefox still shows a warning:**

The settings below address an untrusted issuer. They do not fix a missing localhost SAN or a certificate marked `CA:TRUE` being used as a server certificate; Firefox can still reject that certificate after import. A browser exception does not satisfy this extension's warning-free verification requirement.

1. Open **☰ → Settings → Privacy & Security** and search Settings for **certificates**. Expand **Advanced settings** if the Certificates controls are there.
2. On Windows or macOS, enable **Allow Firefox to automatically trust third-party root certificates you install** if it is disabled, restart Firefox, and retry.
3. On Linux, or if a separate import is still needed, click **View Certificates… → Authorities → Import…**. Select your `nginx/cert.pem`, enable **Trust this CA to identify websites**, and click **OK**.
4. Restart Firefox and repeat the verification above. See [Mozilla's certificate-authority guidance](https://support.mozilla.org/en-US/kb/setting-certificate-authorities-firefox).

**If Chrome / Chromium on Linux still shows a warning:**

1. Enter **chrome://settings/certificates** in the address bar and open **Manage Certificates** if shown.
2. Open the local/custom trusted-certificate area (**Authorities** in the older manager), click **Import**, and select `nginx/cert.pem`. Enable trust for identifying websites if prompted.
3. Restart the browser and repeat verification. See [Chromium's Linux certificate-management guide](https://chromium.googlesource.com/chromium/src/+/refs/heads/main/docs/linux/cert_management.md) if your installed browser uses different labels.

After saving your evidence, remove the lab certificate from the OS and browser stores where you imported it when you are finished using it. On Ubuntu/Debian, remove only your `/usr/local/share/ca-certificates/huskyhub.crt` copy and run `sudo update-ca-certificates --fresh`.

### Extra-Credit Write-Up Questions

Answer both questions to receive the **0.5 extra-credit points** for this extension. Include both questions and your answers, labeled **EC1** and **EC2**, in an extra-credit subsection of your lab's **Write-Up Questions** section, along with your verification evidence.

**EC1.** Before importing your self-signed certificate, the browser displayed a warning even though the connection used HTTPS. What security property was missing? Explain what changed after you explicitly trusted the certificate and whether the encryption itself changed.

**EC2.** After trusting your certificate on your laptop, would a classmate’s untouched laptop automatically trust it? Explain where trust was established and how this differs from using a certificate issued by a publicly trusted Certificate Authority.
