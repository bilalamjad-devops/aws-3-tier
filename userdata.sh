#!/bin/bash
set -e

# ─────────────────────────────────────
# INSTALL PACKAGES
# ─────────────────────────────────────
dnf update -y
dnf install -y httpd php php-mysqli

systemctl enable httpd
systemctl start httpd

# ─────────────────────────────────────
# FETCH EC2 METADATA (IMDSv2 secure)
# ─────────────────────────────────────
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

INSTANCE_ID=$(curl -s \
  -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)

AVAILABILITY_ZONE=$(curl -s \
  -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/availability-zone)

# ─────────────────────────────────────
# WRITE THE PHP APPLICATION
# Terraform templatefile() has already
# injected db_host, db_name, etc. above.
# ─────────────────────────────────────
cat > /var/www/html/index.php << 'PHPEOF'
<?php
// ── DB credentials injected by Terraform user_data ──
$db_host = "${db_host}";
$db_name = "${db_name}";
$db_user = "${db_user}";
$db_pass = "${db_password}";

// ── EC2 metadata injected by bash above ──
$instance_id       = getenv('INSTANCE_ID')       ?: 'unknown';
$availability_zone = getenv('AZ')                 ?: 'unknown';

$msg   = "";
$error = "";
$rows  = [];

// ── Connect to RDS ──
$conn = new mysqli($db_host, $db_user, $db_pass, $db_name);
if ($conn->connect_error) {
    $error = "DB connection failed: " . $conn->connect_error;
} else {
    // Create table if it does not exist yet
    $conn->query("
        CREATE TABLE IF NOT EXISTS users (
            id        INT AUTO_INCREMENT PRIMARY KEY,
            name      VARCHAR(100) NOT NULL,
            email     VARCHAR(100) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ");

    // Handle form submission
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $name  = $conn->real_escape_string(trim($_POST['name']  ?? ''));
        $email = $conn->real_escape_string(trim($_POST['email'] ?? ''));
        if ($name && $email) {
            $conn->query("INSERT INTO users (name, email) VALUES ('$name', '$email')");
            $msg = "✓ Record saved to RDS successfully!";
        }
    }

    // Fetch all saved records
    $result = $conn->query("SELECT * FROM users ORDER BY created_at DESC");
    if ($result) {
        while ($row = $result->fetch_assoc()) {
            $rows[] = $row;
        }
    }

    $conn->close();
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>EC2 + RDS Lab</title>
  <link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;600&family=IBM+Plex+Sans:wght@300;400;600&display=swap" rel="stylesheet">
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

    :root {
      --aws-orange : #FF9900;
      --aws-dark   : #232F3E;
      --aws-darker : #131921;
      --surface    : #1a2332;
      --card       : #1e2d3d;
      --border     : #2d4159;
      --text       : #e8edf2;
      --muted      : #8a9bb0;
      --green      : #3ddc84;
      --red        : #ff6b6b;
    }

    body {
      font-family: 'IBM Plex Sans', sans-serif;
      background: var(--aws-darker);
      color: var(--text);
      min-height: 100vh;
      padding: 0;
    }

    /* ── TOP NAV BAR ── */
    .topbar {
      background: var(--aws-dark);
      border-bottom: 2px solid var(--aws-orange);
      padding: 12px 32px;
      display: flex;
      align-items: center;
      gap: 16px;
    }
    .topbar .logo {
      font-family: 'IBM Plex Mono', monospace;
      font-weight: 600;
      font-size: 22px;
      color: var(--aws-orange);
      letter-spacing: -1px;
    }
    .topbar .tagline {
      font-size: 12px;
      color: var(--muted);
      letter-spacing: 2px;
      text-transform: uppercase;
    }

    /* ── MAIN LAYOUT ── */
    .layout {
      max-width: 960px;
      margin: 40px auto;
      padding: 0 24px;
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 24px;
    }

    /* ── CARD ── */
    .card {
      background: var(--card);
      border: 1px solid var(--border);
      border-radius: 10px;
      padding: 28px;
      position: relative;
      overflow: hidden;
    }
    .card::before {
      content: '';
      position: absolute;
      top: 0; left: 0; right: 0;
      height: 3px;
      background: linear-gradient(90deg, var(--aws-orange), #ffb347);
    }
    .card.full-width { grid-column: 1 / -1; }

    .card-label {
      font-size: 10px;
      font-weight: 600;
      letter-spacing: 3px;
      text-transform: uppercase;
      color: var(--aws-orange);
      margin-bottom: 16px;
    }
    .card h2 {
      font-size: 18px;
      font-weight: 600;
      margin-bottom: 20px;
      color: var(--text);
    }

    /* ── INSTANCE INFO PILLS ── */
    .info-row {
      display: flex;
      flex-direction: column;
      gap: 12px;
    }
    .info-item {
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 6px;
      padding: 12px 16px;
    }
    .info-item .label {
      font-size: 10px;
      letter-spacing: 2px;
      text-transform: uppercase;
      color: var(--muted);
      margin-bottom: 6px;
    }
    .info-item .value {
      font-family: 'IBM Plex Mono', monospace;
      font-size: 15px;
      font-weight: 600;
      color: var(--aws-orange);
    }

    /* ── STATUS DOT ── */
    .status-dot {
      display: inline-block;
      width: 8px; height: 8px;
      border-radius: 50%;
      background: var(--green);
      box-shadow: 0 0 8px var(--green);
      margin-right: 8px;
      animation: pulse 2s infinite;
    }
    @keyframes pulse {
      0%, 100% { opacity: 1; }
      50%       { opacity: 0.4; }
    }

    /* ── FORM ── */
    .form-group { margin-bottom: 16px; }
    .form-group label {
      display: block;
      font-size: 12px;
      letter-spacing: 1px;
      text-transform: uppercase;
      color: var(--muted);
      margin-bottom: 8px;
    }
    .form-group input {
      width: 100%;
      padding: 12px 16px;
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 6px;
      color: var(--text);
      font-family: 'IBM Plex Sans', sans-serif;
      font-size: 14px;
      outline: none;
      transition: border-color 0.2s;
    }
    .form-group input:focus { border-color: var(--aws-orange); }
    .form-group input::placeholder { color: var(--muted); }

    .btn-submit {
      width: 100%;
      padding: 13px;
      background: var(--aws-orange);
      color: #000;
      border: none;
      border-radius: 6px;
      font-family: 'IBM Plex Sans', sans-serif;
      font-weight: 600;
      font-size: 14px;
      cursor: pointer;
      letter-spacing: 1px;
      text-transform: uppercase;
      transition: opacity 0.2s, transform 0.1s;
    }
    .btn-submit:hover  { opacity: 0.88; }
    .btn-submit:active { transform: scale(0.98); }

    /* ── MESSAGES ── */
    .msg-success {
      background: rgba(61, 220, 132, 0.1);
      border: 1px solid var(--green);
      border-radius: 6px;
      padding: 12px 16px;
      color: var(--green);
      font-size: 14px;
      margin-top: 16px;
    }
    .msg-error {
      background: rgba(255, 107, 107, 0.1);
      border: 1px solid var(--red);
      border-radius: 6px;
      padding: 12px 16px;
      color: var(--red);
      font-size: 14px;
      margin-top: 16px;
    }

    /* ── RECORDS TABLE ── */
    .records-table {
      width: 100%;
      border-collapse: collapse;
      margin-top: 8px;
      font-size: 14px;
    }
    .records-table th {
      background: var(--surface);
      color: var(--muted);
      font-size: 10px;
      letter-spacing: 2px;
      text-transform: uppercase;
      padding: 10px 14px;
      text-align: left;
      border-bottom: 1px solid var(--border);
    }
    .records-table td {
      padding: 12px 14px;
      border-bottom: 1px solid var(--border);
      color: var(--text);
      font-family: 'IBM Plex Mono', monospace;
      font-size: 13px;
    }
    .records-table tr:last-child td { border-bottom: none; }
    .records-table tr:hover td { background: rgba(255,153,0,0.04); }

    .empty-state {
      text-align: center;
      padding: 32px;
      color: var(--muted);
      font-size: 14px;
    }
    .empty-state .icon { font-size: 32px; margin-bottom: 10px; }

    /* ── DB STATUS BADGE ── */
    .db-badge {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 20px;
      padding: 4px 12px;
      font-size: 11px;
      color: var(--muted);
      margin-bottom: 20px;
    }
    .db-badge.connected { border-color: var(--green); color: var(--green); }
    .db-badge.error-state { border-color: var(--red); color: var(--red); }
  </style>
</head>
<body>

<div class="topbar">
  <div class="logo">aws</div>
  <div class="tagline">EC2 + RDS Lab — Three-Tier Demo</div>
</div>

<div class="layout">

  <!-- ── LEFT: INSTANCE INFO ── -->
  <div class="card">
    <div class="card-label">EC2 Instance Info</div>
    <h2><span class="status-dot"></span>Server Identity</h2>
    <div class="info-row">
      <div class="info-item">
        <div class="label">Instance ID</div>
        <div class="value"><?= htmlspecialchars($instance_id) ?></div>
      </div>
      <div class="info-item">
        <div class="label">Availability Zone</div>
        <div class="value"><?= htmlspecialchars($availability_zone) ?></div>
      </div>
      <div class="info-item">
        <div class="label">RDS Endpoint</div>
        <div class="value" style="font-size:11px; word-break:break-all;"><?= htmlspecialchars($db_host) ?></div>
      </div>
    </div>
  </div>

  <!-- ── RIGHT: FORM ── -->
  <div class="card">
    <div class="card-label">Data Layer</div>
    <h2>Save to RDS</h2>

    <?php if ($error): ?>
      <div class="db-badge error-state">✗ DB Disconnected</div>
    <?php else: ?>
      <div class="db-badge connected">✓ Connected to RDS MySQL</div>
    <?php endif; ?>

    <?php if (!$error): ?>
    <form method="POST">
      <div class="form-group">
        <label>Name</label>
        <input type="text" name="name" placeholder="e.g. Ahmed Khan" required>
      </div>
      <div class="form-group">
        <label>Email</label>
        <input type="email" name="email" placeholder="e.g. ahmed@example.com" required>
      </div>
      <button type="submit" class="btn-submit">Save to Database →</button>
    </form>

    <?php if ($msg): ?>
      <div class="msg-success"><?= htmlspecialchars($msg) ?></div>
    <?php endif; ?>

    <?php else: ?>
      <div class="msg-error"><?= htmlspecialchars($error) ?></div>
    <?php endif; ?>
  </div>

  <!-- ── BOTTOM: RECORDS TABLE ── -->
  <div class="card full-width">
    <div class="card-label">RDS Records</div>
    <h2>Saved Entries from Database</h2>

    <?php if (empty($rows)): ?>
      <div class="empty-state">
        <div class="icon">🗄️</div>
        No records yet — submit the form above to save your first entry to RDS.
      </div>
    <?php else: ?>
    <table class="records-table">
      <thead>
        <tr>
          <th>ID</th>
          <th>Name</th>
          <th>Email</th>
          <th>Saved At</th>
        </tr>
      </thead>
      <tbody>
        <?php foreach ($rows as $row): ?>
        <tr>
          <td><?= htmlspecialchars($row['id']) ?></td>
          <td><?= htmlspecialchars($row['name']) ?></td>
          <td><?= htmlspecialchars($row['email']) ?></td>
          <td><?= htmlspecialchars($row['created_at']) ?></td>
        </tr>
        <?php endforeach; ?>
      </tbody>
    </table>
    <?php endif; ?>
  </div>

</div>
</body>
</html>
PHPEOF

# ─────────────────────────────────────
# INJECT METADATA INTO ENV FOR PHP
# We write env vars into Apache's envvars
# so PHP can read them via getenv()
# ─────────────────────────────────────
echo "export INSTANCE_ID=\"$INSTANCE_ID\""       >> /etc/sysconfig/httpd
echo "export AZ=\"$AVAILABILITY_ZONE\""          >> /etc/sysconfig/httpd

# Pass env vars to PHP via Apache SetEnv
cat >> /etc/httpd/conf/httpd.conf << APACHEEOF

SetEnv INSTANCE_ID "$INSTANCE_ID"
SetEnv AZ "$AVAILABILITY_ZONE"
APACHEEOF

# Rename default index.html so PHP takes over
rm -f /var/www/html/index.html

systemctl restart httpd
