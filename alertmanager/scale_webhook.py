#!/usr/bin/env python3
import json
import os
import shlex
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent
REPO_DIR = BASE_DIR.parent
TERRAFORM_DIR = REPO_DIR / "terraform"
ADD_NODE_SCRIPT = TERRAFORM_DIR / "add-node.sh"
REMOVE_NODE_SCRIPT = TERRAFORM_DIR / "remove-node.sh"
WORKFLOW_SCRIPT = REPO_DIR / "ansible-web" / "provision-ec2-and-run-ansible.sh"
DEFAULT_ENV_FILE = BASE_DIR / "scale-webhook.env"


def load_env_file(path):
    if not path.exists():
        return

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue

        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip().strip("'\""))


load_env_file(Path(os.environ.get("SCALE_WEBHOOK_ENV_FILE", str(DEFAULT_ENV_FILE))))

HOST = os.environ.get("SCALE_WEBHOOK_HOST", "127.0.0.1")
PORT = int(os.environ.get("SCALE_WEBHOOK_PORT", "5001"))
COOLDOWN_SECONDS = int(os.environ.get("SCALE_WEBHOOK_COOLDOWN_SECONDS", "1800"))
MIN_TERRAFORM_NODES = int(os.environ.get("SCALE_WEBHOOK_MIN_TERRAFORM_NODES", "1"))
SSH_USER = os.environ.get("SCALE_SSH_USER", "ubuntu")
SSH_SERVER_IP = os.environ.get("SCALE_SERVER_IP", "")
SSH_TARGET = os.environ.get("SCALE_SSH_TARGET", f"{SSH_USER}@{SSH_SERVER_IP}" if SSH_SERVER_IP else "")
SSH_KEY = os.environ.get("SCALE_SSH_KEY", str(REPO_DIR / "ansible-web" / "kien.pem"))
SSH_PORT = os.environ.get("SCALE_SSH_PORT", "22")
REMOTE_REPO_DIR = os.environ.get("SCALE_REPO_DIR", str(REPO_DIR))
REMOTE_WORKFLOW_DIR = os.environ.get("SCALE_WORKFLOW_DIR", str(REPO_DIR / "ansible-web"))
REMOTE_WORKFLOW_SCRIPT = os.environ.get(
    "SCALE_WORKFLOW_SCRIPT",
    "provision-ec2-and-run-ansible.sh",
)
SSH_COMMAND = os.environ.get(
    "SCALE_SSH_COMMAND",
    f"cd {shlex.quote(REMOTE_WORKFLOW_DIR)} && bash ./{shlex.quote(REMOTE_WORKFLOW_SCRIPT)}",
)
SCALE_DOWN_SSH_COMMAND = os.environ.get(
    "SCALE_DOWN_SSH_COMMAND",
    (
        f"cd {shlex.quote(REMOTE_REPO_DIR.rstrip('/') + '/terraform')} "
        f"&& MIN_TERRAFORM_NODES={MIN_TERRAFORM_NODES} bash ./remove-node.sh"
    ),
)

STATE_DIR = Path(os.environ.get("SCALE_WEBHOOK_STATE_DIR", str(BASE_DIR)))
LAST_SCALE_UP_FILE = STATE_DIR / ".last_scale_up_ec2"
LAST_SCALE_DOWN_FILE = STATE_DIR / ".last_scale_down_ec2"
LOCK_FILE = STATE_DIR / ".scale_ec2.lock"
LOG_FILE = STATE_DIR / "scale_webhook.log"


def scale_action(payload):
    if payload.get("status") != "firing":
        return None

    for alert in payload.get("alerts", []):
        labels = alert.get("labels", {})
        if (
            alert.get("status") == "firing"
            and labels.get("alertname") == "HighAverageNodeCpuUsage"
            and labels.get("action") == "scale-ec2"
        ):
            return "up"

        if (
            alert.get("status") == "firing"
            and labels.get("alertname") == "LowAverageNodeCpuUsage"
            and labels.get("action") == "scale-down-ec2"
        ):
            return "down"

    return None


def last_scale_file(action):
    return LAST_SCALE_DOWN_FILE if action == "down" else LAST_SCALE_UP_FILE


def cooldown_remaining(action):
    try:
        last_scale = float(last_scale_file(action).read_text(encoding="utf-8").strip())
    except (FileNotFoundError, ValueError):
        return 0

    elapsed = time.time() - last_scale
    return max(0, int(COOLDOWN_SECONDS - elapsed))


def mark_scaled(action):
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    last_scale_file(action).write_text(str(time.time()), encoding="utf-8")


def log_event(message):
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    line = f"{time.strftime('%Y-%m-%dT%H:%M:%S%z')} {message}\n"
    with LOG_FILE.open("a", encoding="utf-8") as log_file:
        log_file.write(line)
    print(message, flush=True)


def acquire_lock():
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    try:
        fd = os.open(str(LOCK_FILE), os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    except FileExistsError:
        return False

    with os.fdopen(fd, "w", encoding="utf-8") as lock_file:
        lock_file.write(str(os.getpid()))
    return True


def release_lock():
    try:
        LOCK_FILE.unlink()
    except FileNotFoundError:
        pass


def run_scale(action):
    if SSH_TARGET:
        ssh_command = SCALE_DOWN_SSH_COMMAND if action == "down" else SSH_COMMAND
        command = [
            "ssh",
            "-p",
            SSH_PORT,
            "-o",
            "BatchMode=yes",
            "-o",
            "StrictHostKeyChecking=accept-new",
        ]

        if SSH_KEY:
            command.extend(["-i", SSH_KEY])

        command.extend([SSH_TARGET, ssh_command])

        result = subprocess.run(
            command,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=int(os.environ.get("SCALE_WEBHOOK_TIMEOUT_SECONDS", "1800")),
        )

        if result.returncode != 0:
            raise RuntimeError(result.stdout)

        return result.stdout

    if action == "down":
        if not REMOVE_NODE_SCRIPT.exists():
            raise FileNotFoundError(f"Missing scale-down script: {REMOVE_NODE_SCRIPT}")

        command = ["bash", str(REMOVE_NODE_SCRIPT)]
        cwd = str(TERRAFORM_DIR)
        env = os.environ.copy()
        env.setdefault("MIN_TERRAFORM_NODES", str(MIN_TERRAFORM_NODES))
    else:
        env = None

        if WORKFLOW_SCRIPT.exists():
            command = ["bash", str(WORKFLOW_SCRIPT)]
            cwd = str(REPO_DIR)
        else:
            if not ADD_NODE_SCRIPT.exists():
                raise FileNotFoundError(f"Missing scale script: {ADD_NODE_SCRIPT}")

            command = ["bash", str(ADD_NODE_SCRIPT)]
            cwd = str(TERRAFORM_DIR)

    result = subprocess.run(
        command,
        cwd=cwd,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=int(os.environ.get("SCALE_WEBHOOK_TIMEOUT_SECONDS", "1800")),
    )

    if result.returncode != 0:
        raise RuntimeError(result.stdout)

    return result.stdout


def run_scale_background(action):
    try:
        log_event(f"Starting EC2 scale-{action} command")
        output = run_scale(action)
        mark_scaled(action)
        log_event(f"EC2 scale-{action} command completed")
        if output:
            log_event(output[-4000:])
    except Exception as exc:
        log_event(f"EC2 scale-{action} command failed: {exc}")
    finally:
        release_lock()


class ScaleWebhookHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != "/scale-ec2":
            self.send_json(404, {"error": "not found"})
            return

        content_length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(content_length)

        try:
            payload = json.loads(body.decode("utf-8"))
        except json.JSONDecodeError:
            self.send_json(400, {"error": "invalid json"})
            return

        action = scale_action(payload)
        if not action:
            self.send_json(202, {"status": "ignored"})
            return

        remaining = cooldown_remaining(action)
        if remaining > 0:
            self.send_json(202, {"status": "cooldown", "remaining_seconds": remaining})
            return

        if not acquire_lock():
            self.send_json(202, {"status": "already_running"})
            return

        thread = threading.Thread(target=run_scale_background, args=(action,), daemon=True)
        thread.start()
        self.send_json(202, {"status": "scale_started", "action": action})

    def log_message(self, fmt, *args):
        print("%s - %s" % (self.address_string(), fmt % args), flush=True)

    def send_json(self, status, payload):
        response = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(response)))
        self.end_headers()
        self.wfile.write(response)


if __name__ == "__main__":
    server = ThreadingHTTPServer((HOST, PORT), ScaleWebhookHandler)
    print(f"Scale webhook listening on http://{HOST}:{PORT}/scale-ec2", flush=True)
    server.serve_forever()
