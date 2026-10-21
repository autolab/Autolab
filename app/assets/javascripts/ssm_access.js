// Behavior for users/ssm_access.html.erb. Page values arrive as data
// attributes on #ssm-page.

// Connection details used to build the commands. username and instanceId
// can also arrive later in a Tango status response.
const ssmDetails = {};

// The Rails route that reports the Tango job status.
let ssmStatusUrl = "";

// Private key used by the file transfer commands. Matches the path the SSH
// Keys page tells instructors to generate; change it here if that changes.
const SSM_SSH_KEY_PATH = "~/.ssh/id_ed25519_autolab";

document.addEventListener("DOMContentLoaded", function() {
    const page = document.getElementById("ssm-page");

    if (!page) {
        return;
    }

    ssmDetails.username = page.dataset.username || "";
    ssmDetails.instanceId = page.dataset.instanceId || "";
    ssmDetails.region = page.dataset.region || "";
    ssmStatusUrl = page.dataset.statusUrl;
    renderSsmGuide();

    document.getElementById("create-button")
        .addEventListener("click", function() {
            startAwsOperation("create");
        });

    document.getElementById("regenerate-button")
        .addEventListener("click", function() {
            const confirmed = confirm(
                "Generate a new access key? Your current access key " +
                "will be deleted and stop working."
            );

            if (confirmed) {
                startAwsOperation("regenerate");
            }
        });

    // A job still running from before a refresh. The server already
    // rendered SET UP as the active tab for this case.
    if (page.dataset.jobStatus === "in_progress") {
        const mode =
            page.dataset.accountCreated === "true" ? "regenerate" : "create";

        setActionsDisabled(true);
        showStatus("In progress:", "Operation in progress...", "info");

        pollProvisionStatus(mode);
    }
});

// ----- Tabs -----

// Switch to a tab by its panel id. Tabs are initialized by app-level.js;
// a disabled tab cannot be selected, so enable it first.
function selectTab(panelId) {
    const tabs = M.Tabs.getInstance(document.getElementById("ssm-tabs"));

    if (tabs) {
        tabs.select(panelId);
        return;
    }

    const link = document.querySelector(
        '#ssm-tabs a[href="#' + panelId + '"]'
    );

    if (link) {
        link.click();
    }
}

function enableAccountTabs() {
    document.querySelectorAll("#ssm-tabs [data-needs-account]")
        .forEach(function(tab) {
            tab.classList.remove("disabled");
        });
}

// ----- Commands -----

function renderSsmGuide() {
    const username = ssmDetails.username || "<username>";
    const instanceId = ssmDetails.instanceId || "<instance-id>";
    const profile = "autolab-" + username;
    const configureCommand = "aws configure --profile " + profile;
    const regionFlag = ssmDetails.region
        ? " --region " + ssmDetails.region
        : "";

    document.getElementById("cmd-configure").textContent =
        configureCommand;

    document.getElementById("cmd-start-session").textContent =
        "aws ssm start-session --target " + instanceId +
        " --profile " + profile + regionFlag;

    document.getElementById("instance-id").textContent =
        ssmDetails.instanceId;
    document.getElementById("instance-id").style.display =
        ssmDetails.instanceId ? "" : "none";
    document.getElementById("copy-instance-id-button").style.display =
        ssmDetails.instanceId ? "" : "none";
    document.getElementById("instance-id-missing").style.display =
        ssmDetails.instanceId ? "none" : "";

    const regionPrompt = document.getElementById("prompt-region");
    regionPrompt.textContent = "";

    if (ssmDetails.region) {
        const code = document.createElement("code");
        code.textContent = ssmDetails.region;
        regionPrompt.appendChild(code);
    } else {
        // Tango's IAM config could not be read (or has no region).
        regionPrompt.textContent =
            "The AWS region of the instance (ask your Autolab administrator)";
    }

    document.querySelectorAll("[data-ssm-username]").forEach(function(el) {
        el.textContent = ssmDetails.username;
    });

    document.querySelectorAll("[data-ssm-profile]").forEach(function(el) {
        el.textContent = profile;
    });

    document.querySelectorAll("[data-ssm-configure-command]")
        .forEach(function(el) {
            el.textContent = configureCommand;
        });

    renderTransferCommands(username, instanceId, profile, regionFlag);
}

// SCP over SSH, tunnelled through Session Manager's AWS-StartSSHSession.
function renderTransferCommands(username, instanceId, profile, regionFlag) {
    const sessionArgs = "--document-name AWS-StartSSHSession";
    const remoteHome = "/home/" + username + "/";
    const proxyCommand =
        "aws ssm start-session --target %h " + sessionArgs +
        " --parameters portNumber=%p --profile " + profile + regionFlag;
    const sshOptions = [
        "  -i " + SSM_SSH_KEY_PATH + " \\",
        "  -o 'ProxyCommand=" + proxyCommand + "' \\"
    ];
    const scpOptions = ["scp \\"].concat(sshOptions);

    // Opens a shell over SSH, to check the key before transferring files.
    document.getElementById("cmd-ssh-test").textContent = ["ssh \\"]
        .concat(sshOptions, ["  " + username + "@" + instanceId])
        .join("\n");

    document.getElementById("cmd-scp-upload").textContent = scpOptions.concat([
        "  ./file.txt \\",
        "  " + username + "@" + instanceId + ":" + remoteHome
    ]).join("\n");

    document.getElementById("cmd-scp-download").textContent = scpOptions.concat([
        "  " + username + "@" + instanceId + ":" + remoteHome + "file.txt \\",
        "  ."
    ]).join("\n");

    document.getElementById("cmd-ssh-config").textContent = [
        "Host " + instanceId,
        "    User " + username,
        "    IdentityFile " + SSM_SSH_KEY_PATH,
        "    ProxyCommand sh -c \"aws ssm start-session --target %h " +
            sessionArgs + " --parameters 'portNumber=%p' --profile " +
            profile + regionFlag + "\""
    ].join("\n");

    document.getElementById("cmd-scp-upload-short").textContent =
        "scp ./file.txt " + instanceId + ":" + remoteHome;

    document.getElementById("cmd-scp-download-short").textContent =
        "scp " + instanceId + ":" + remoteHome + "file.txt .";

    document.querySelectorAll("[data-ssm-ssh-key]").forEach(function(el) {
        el.textContent = SSM_SSH_KEY_PATH;
    });
}

// Show one of the Transfer Files options on the ACCESS tab.
function showTransferOption(optionId) {
    document.querySelectorAll(".ssm-transfer-option").forEach(function(panel) {
        panel.style.display = panel.id === optionId ? "" : "none";
    });

    document.querySelectorAll("[data-transfer-option]").forEach(function(button) {
        const selected = button.dataset.transferOption === optionId;

        button.classList.toggle("active", selected);
        button.setAttribute("aria-pressed", selected ? "true" : "false");
    });
}

// Picks up the username and instance ID from a Tango response when the
// page was rendered without them.
function applyResponseDetails(data) {
    let changed = false;

    if (data.iamUsername && data.iamUsername !== ssmDetails.username) {
        ssmDetails.username = data.iamUsername;
        changed = true;
    }

    if (data.instanceId && !ssmDetails.instanceId) {
        ssmDetails.instanceId = data.instanceId;
        changed = true;
    }

    if (changed) {
        renderSsmGuide();
    }
}

// ----- Operation state -----

function setActionsDisabled(disabled) {
    document.getElementById("create-button").disabled = disabled;
    document.getElementById("regenerate-button").disabled = disabled;
}

function showStatus(title, message, kind) {
    const status = document.getElementById("creation-status");

    status.className = "alert alert-" + kind;
    document.getElementById("status-title").innerText = title;
    document.getElementById("status-text").innerText = message;
    status.style.display = "block";
}

function hideStatus() {
    document.getElementById("creation-status").style.display = "none";
}

async function startAwsOperation(mode) {
    const button = document.getElementById(
        mode === "create" ? "create-button" : "regenerate-button"
    );

    setActionsDisabled(true);
    button.innerText =
        mode === "create" ? "CREATING..." : "REGENERATING...";

    document.getElementById("creation-error").style.display = "none";

    if (mode === "regenerate") {
        // The old key is about to be deleted; don't leave it on screen.
        clearCredentials();
    }

    showStatus(
        "In progress:",
        mode === "create"
            ? "Starting account creation..."
            : "Starting access key regeneration...",
        "info"
    );

    try {
        const response = await fetch(button.dataset.url, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "X-CSRF-Token":
                document.querySelector('meta[name="csrf-token"]').content
            }
        });

        const data = await response.json();

        if (!response.ok) {
            throw new Error(
                data.error || "Failed to start AWS operation."
            );
        }

        applyResponseDetails(data);

        if (data.statusId === 2) {
            operationFinished(mode);
        } else if (data.statusId === 255) {
            operationFailed(
                mode,
                data.statusMsg || "AWS operation failed."
            );
            return;
        }

        if (data.accessKey) {
            showCredentials(data.accessKey);
        }

        if (data.statusId !== 2) {
            pollProvisionStatus(mode);
        }

    } catch (error) {
        operationFailed(mode, error.message);
    }
}

async function pollProvisionStatus(mode) {
    try {
        const response = await fetch(ssmStatusUrl);

        const data = await response.json();

        if (!response.ok) {
            throw new Error(
                data.error || "Failed to retrieve AWS job status."
            );
        }

        applyResponseDetails(data);

        if (data.statusMsg) {
            document.getElementById("status-text").innerText =
                data.statusMsg;
        }

        if (data.statusId === 2) {
            operationFinished(mode);
        } else if (data.statusId === 255) {
            operationFailed(
                mode,
                data.statusMsg || "AWS operation failed."
            );
            return;
        }

        if (data.accessKey) {
            showCredentials(data.accessKey);
        }

        if (data.statusId !== 2) {
            setTimeout(function() {
                pollProvisionStatus(mode);
            }, 2000);
        }

    } catch (error) {
        operationFailed(mode, error.message);
    }
}

function operationFinished(mode) {
    document.getElementById("create-button").innerText = "CREATE USER";
    document.getElementById("regenerate-button").innerText =
        "REGENERATE ACCESS KEY";

    // The new credentials on SET UP (or the "Account Ready" banner) replace
    // the status message.
    hideStatus();

    if (mode === "create") {
        document.getElementById("create-section").style.display = "none";
        document.getElementById("setup-account-section").style.display =
            "block";
        enableAccountTabs();
    }

    selectTab("ssm-setup");
    setActionsDisabled(false);
}

function operationFailed(mode, message) {
    hideStatus();

    const errorBox = document.getElementById("creation-error");

    errorBox.innerText =
        (mode === "create"
            ? "Account creation failed: "
            : "Access key regeneration failed: ") + message;
    errorBox.style.display = "block";

    document.getElementById("create-button").innerText = "CREATE USER";
    document.getElementById("regenerate-button").innerText =
        "REGENERATE ACCESS KEY";

    setActionsDisabled(false);
}

// ----- Credentials -----

// The secret is only ever held in this input for the current page. A new
// key always lands on SET UP.
function showCredentials(accessKey) {
    document.getElementById("access-key-id").textContent =
        accessKey.accessKeyId;

    const secretField = document.getElementById("secret-access-key");
    secretField.value = accessKey.secretAccessKey;
    secretField.type = "password";
    document.getElementById("show-secret-button").innerText = "SHOW";

    document.getElementById("no-credentials-note").style.display = "none";

    const panel = document.getElementById("credentials-panel");
    panel.style.display = "block";

    selectTab("ssm-setup");
    panel.scrollIntoView({ behavior: "smooth", block: "start" });
}

function clearCredentials() {
    document.getElementById("access-key-id").textContent = "";
    document.getElementById("secret-access-key").value = "";
    document.getElementById("credentials-panel").style.display = "none";
    document.getElementById("no-credentials-note").style.display = "";
}

function toggleSecret() {
    const field =
        document.getElementById("secret-access-key");

    const button =
        document.getElementById("show-secret-button");

    if (field.type === "password") {
        field.type = "text";
        button.innerText = "HIDE";
    } else {
        field.type = "password";
        button.innerText = "SHOW";
    }
}

// ----- Copy helpers -----

async function writeClipboard(value) {
    // navigator.clipboard only exists on HTTPS or localhost.
    if (navigator.clipboard && window.isSecureContext) {
        await navigator.clipboard.writeText(value);
        return;
    }

    const scratch = document.createElement("textarea");
    scratch.value = value;
    scratch.setAttribute("readonly", "");
    scratch.style.position = "fixed";
    scratch.style.opacity = "0";
    document.body.appendChild(scratch);
    scratch.select();
    document.execCommand("copy");
    document.body.removeChild(scratch);
}

function flashCopied(button) {
    if (!button) {
        return;
    }

    if (!button.dataset.label) {
        button.dataset.label = button.innerText;
    }

    button.innerText = "COPIED";
    setTimeout(function() {
        button.innerText = button.dataset.label;
    }, 1500);
}

async function copyText(id, button) {
    const value =
        document.getElementById(id).textContent;

    await writeClipboard(value);
    flashCopied(button);
}

async function copyValue(id, button) {
    const value =
        document.getElementById(id).value;

    await writeClipboard(value);
    flashCopied(button);
}
