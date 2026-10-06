FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8

# System packages. Chromium's shared libraries come from `playwright install-deps`
# in the next step; the browser itself is downloaded into the home volume at
# first start (entrypoint.sh). gosu lets the entrypoint drop root->agent after
# remapping the uid/gid to PUID/PGID.
# End users add their own apt packages via Dockerfile.user, not here.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git tmux ripgrep fd-find jq btop build-essential \
      python3-venv unzip vim less openssh-client openssh-server tzdata gosu rsync \
    && ln -s /usr/bin/fdfind /usr/local/bin/fd \
    && rm -f /etc/ssh/ssh_host_* \
    && mkdir -p /run/sshd \
    && rm -rf /var/lib/apt/lists/*

# Unpinned on purpose; tools themselves are updated inside with `mise up`.
RUN curl -fsSL https://mise.jdx.dev/mise-latest-linux-x64 -o /usr/local/bin/mise \
    && chmod +x /usr/local/bin/mise

# Throwaway node (Ubuntu's is too old for playwright) just for the system libs.
RUN MISE_DATA_DIR=/tmp/mise mise exec node@lts -- npx -y playwright install-deps chromium \
    && rm -rf /tmp/mise /root/.npm /var/lib/apt/lists/*

# Placeholder ids that entrypoint.sh remaps to PUID/PGID at start. No sudo on
# purpose: the container is the containment boundary.
# ubuntu:24.04 ships a default `ubuntu` user at 1000:1000; drop it first.
RUN (userdel -r ubuntu 2>/dev/null; groupdel ubuntu 2>/dev/null; true) \
    && groupadd -g 1000 agent \
    && useradd -u 1000 -g agent -m -s /bin/bash -p '*' agent

COPY agent-instructions.md /etc/roost/AGENTS.md
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY sshd_config /etc/roost/sshd_config

# PATH for login shells (docker exec bash -l) + aliases for interactive ones.
RUN chmod +x /usr/local/bin/entrypoint.sh \
    && echo 'export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"' > /etc/profile.d/roost.sh \
    && printf '%s\n' \
      "eval \"\$(/usr/local/bin/mise activate bash)\"" \
      "alias a='claude'" \
      "alias c='opencode'" \
      "alias cx='claude --dangerously-skip-permissions'" \
      "alias cy='codex --approve-for-me'" \
      "alias cz='opencode --dangerously-skip-permissions'" >> /etc/bash.bashrc

# Main process starts as root so entrypoint.sh can remap uid/gid, then drops.
WORKDIR /home/agent
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
