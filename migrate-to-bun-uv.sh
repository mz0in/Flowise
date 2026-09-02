#!/usr/bin/env bash

set -Eeuo pipefail

readonly BUN_VERSION="${BUN_VERSION:-1.4.0}"
readonly SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$SCRIPT_DIR")"

log() {
    printf '[bun-uv-migration] %s\n' "$*"
}

die() {
    printf '[bun-uv-migration] ERROR: %s\n' "$*" >&2
    exit 1
}

install_bun() {
    if command -v bun >/dev/null 2>&1; then
        return
    fi

    command -v curl >/dev/null 2>&1 || die 'curl is required to install Bun'
    local installer_dir installer
    installer_dir="$(mktemp -d)"
    installer="$installer_dir/install-bun.sh"
    log "Installing Bun ${BUN_VERSION} with the official installer"
    curl --proto '=https' --tlsv1.2 -fsSL https://bun.sh/install -o "$installer"
    bash "$installer" "bun-v${BUN_VERSION}"
    rm -rf -- "$installer_dir"
    export PATH="${BUN_INSTALL:-$HOME/.bun}/bin:$PATH"
    command -v bun >/dev/null 2>&1 || die 'Bun installation completed but bun is not on PATH'
}

install_uv() {
    if command -v uv >/dev/null 2>&1; then
        return
    fi

    command -v curl >/dev/null 2>&1 || die 'curl is required to install uv'
    local installer_dir installer
    installer_dir="$(mktemp -d)"
    installer="$installer_dir/install-uv.sh"
    log 'Installing uv with the official installer'
    curl --proto '=https' --tlsv1.2 -fsSL https://astral.sh/uv/install.sh -o "$installer"
    env UV_UNMANAGED_INSTALL="$HOME/.local/bin" sh "$installer"
    rm -rf -- "$installer_dir"
    export PATH="$HOME/.local/bin:$PATH"
    command -v uv >/dev/null 2>&1 || die 'uv installation completed but uv is not on PATH'
}

cd "$REPO_ROOT"
[[ -f package.json ]] || die "package.json was not found in $REPO_ROOT"

install_bun
export BUN_MIGRATION_VERSION="$BUN_VERSION"

log 'Converting package manifests and executable configuration'
bun run - <<'BUN_SCRIPT'
import { Glob } from 'bun'

const root = process.cwd()
const bunVersion = process.env.BUN_MIGRATION_VERSION || '1.4.0'
const packageGlob = new Glob('**/package.json')

for await (const relativePath of packageGlob.scan({ cwd: root, onlyFiles: true })) {
    if (relativePath.includes('/node_modules/') || relativePath.startsWith('node_modules/')) continue

    const file = Bun.file(relativePath)
    const pkg = await file.json()
    if (pkg.scripts) {
        for (const [name, command] of Object.entries(pkg.scripts)) {
            if (typeof command !== 'string') continue
            pkg.scripts[name] = command
                .replace(/\bpnpm\s+-r\s+/g, 'bun run --workspaces ')
                .replace(/\bpnpm\s+/g, 'bun run ')
                .replace(/\bnpm\s+run\s+/g, 'bun run ')
                .replace(/(^|(?:&&|;|\|\|)\s+)node\s+/g, '$1bun ')
        }
    }

    if (relativePath === 'package.json') {
        const pnpm = pkg.pnpm || {}
        pkg.overrides = { ...(pnpm.overrides || {}), ...(pkg.overrides || {}) }
        pkg.trustedDependencies = [...new Set([...(pkg.trustedDependencies || []), ...(pnpm.onlyBuiltDependencies || [])])]
        delete pkg.pnpm
        pkg.packageManager = `bun@${bunVersion}`
        pkg.engines = { ...(pkg.engines || {}), bun: `>=${bunVersion}` }
        delete pkg.engines.pnpm
    }

    await Bun.write(relativePath, JSON.stringify(pkg, null, 4) + '\n')
}

const componentsPackagePath = 'packages/components/package.json'
const componentsPackage = await Bun.file(componentsPackagePath).json()
componentsPackage.scripts.build = 'tsc && bun scripts/copy-icons.ts'
delete componentsPackage.devDependencies.gulp
delete componentsPackage.devDependencies['@types/gulp']
await Bun.write(componentsPackagePath, JSON.stringify(componentsPackage, null, 4) + '\n')

const iconCopyScript = [
    "import { mkdir } from 'node:fs/promises'",
    "import { dirname } from 'node:path'",
    '',
    "const iconGlob = new Bun.Glob('nodes/**/*.{jpg,png,svg}')",
    '',
    "for await (const relativePath of iconGlob.scan({ cwd: process.cwd(), onlyFiles: true })) {",
    "    const destination = 'dist/' + relativePath",
    '    await mkdir(dirname(destination), { recursive: true })',
    '    await Bun.write(destination, Bun.file(relativePath))',
    '}',
    ''
].join('\n')
await Bun.write('packages/components/scripts/copy-icons.ts', iconCopyScript)

const serverPackagePath = 'packages/server/package.json'
const serverPackage = await Bun.file(serverPackagePath).json()
serverPackage.scripts.build = 'tsc && rimraf dist/enterprise/emails && bun scripts/copy-email-templates.ts'
delete serverPackage.dependencies.gulp
if (serverPackage.devDependencies) {
    delete serverPackage.devDependencies.gulp
    delete serverPackage.devDependencies['@types/gulp']
}
await Bun.write(serverPackagePath, JSON.stringify(serverPackage, null, 4) + '\n')

const emailCopyScript = [
    "import { mkdir } from 'node:fs/promises'",
    "import { dirname } from 'node:path'",
    '',
    "const templateGlob = new Bun.Glob('src/enterprise/emails/*.hbs')",
    '',
    "for await (const relativePath of templateGlob.scan({ cwd: process.cwd(), onlyFiles: true })) {",
    "    const destination = relativePath.replace('src/', 'dist/')",
    '    await mkdir(dirname(destination), { recursive: true })',
    '    await Bun.write(destination, Bun.file(relativePath))',
    '}',
    ''
].join('\n')
await Bun.write('packages/server/scripts/copy-email-templates.ts', emailCopyScript)

async function replaceIn(path, replacements) {
    let text = await Bun.file(path).text()
    for (const [from, to] of replacements) text = text.split(from).join(to)
    await Bun.write(path, text)
}

await replaceIn('.husky/pre-commit', [
    ['pnpm quick', 'bun run quick'],
    ['pnpm lint-staged', 'bun run lint-staged']
])

await replaceIn('.gitignore', [
    ['## pnpm\n.pnpm-store/\n', '## Bun\n.bun/\n**/bun.lockb\n']
])
await replaceIn('.prettierignore', [['pnpm-lock.yaml', 'bun.lock']])
await Bun.write('bunfig.toml', '[install]\nlinker = "hoisted"\n')

await replaceIn('.github/workflows/main.yml', [
    ["        strategy:\n            matrix:\n                platform: [ubuntu-latest]\n                node-version: [24.15.0]\n        runs-on: ${{ matrix.platform }}", '        runs-on: ubuntu-latest'],
    ['- uses: pnpm/action-setup@v4\n              with:\n                  version: 10.26.0', '- uses: oven-sh/setup-bun@v2\n              with:\n                  bun-version: ' + bunVersion],
    ["            - name: Use Node.js ${{ matrix.node-version }}\n              uses: actions/setup-node@v6\n              with:\n                  node-version: ${{ matrix.node-version }}\n", ''],
    ["                  cache: 'pnpm'\n                  cache-dependency-path: 'pnpm-lock.yaml'\n", ''],
    ['run: pnpm install', 'run: bun install --frozen-lockfile'],
    ['run: pnpm lint', 'run: bun run lint'],
    ['run: pnpm build', 'run: bun run build'],
    ['run: pnpm test:coverage', 'run: bun run test:coverage'],
    ['run: pnpm cypress install', 'run: bunx cypress install'],
    ['start: pnpm start', 'start: bun run --bun start']
])

await replaceIn('.github/workflows/publish-package.yml', [
    ['- uses: pnpm/action-setup@v6\n              with:\n                  version: 10.26.0', '- uses: oven-sh/setup-bun@v2\n              with:\n                  bun-version: ' + bunVersion],
    ['npx semver', 'bunx semver'],
    ['run: pnpm install --frozen-lockfile', 'run: bun install --frozen-lockfile'],
    ['npm pkg get version --prefix "$PACKAGE_PATH"', 'bun pm pkg get version --cwd "$PACKAGE_PATH"'],
    ['npm pkg set version="$NEW_VERSION" --prefix "$PACKAGE_PATH"', 'bun pm pkg set version="$NEW_VERSION" --cwd "$PACKAGE_PATH"'],
    ['run: pnpm --filter "$PACKAGE_NAME" pack --dry-run', 'run: bun pm pack --dry-run --cwd "$PACKAGE_PATH"'],
    ['run: pnpm --filter "$PACKAGE_NAME" publish --no-git-checks --dry-run --tag "$TAG"', 'run: bun publish --dry-run --tag "$TAG" --cwd "$PACKAGE_PATH"'],
    ['run: pnpm --filter "$PACKAGE_NAME" publish --no-git-checks --tag "$TAG"', 'run: bun publish --tag "$TAG" --cwd "$PACKAGE_PATH"'],
    ['                  PACKAGE_NAME: ${{ inputs.package_name }}\n                  TAG:', '                  PACKAGE_NAME: ${{ inputs.package_name }}\n                  PACKAGE_PATH: ${{ inputs.package_path }}\n                  TAG:']
])

await replaceIn('.github/workflows/publish-package.yml', [
    ['            - name: Package contents\n              run: bun pm pack --dry-run --cwd "$PACKAGE_PATH"\n              env:\n                  PACKAGE_NAME: ${{ inputs.package_name }}\n\n', '            - name: Package contents\n              run: bun pm pack --dry-run --cwd "$PACKAGE_PATH"\n              env:\n                  PACKAGE_NAME: ${{ inputs.package_name }}\n                  PACKAGE_PATH: ${{ inputs.package_path }}\n\n']
])

const rootDockerfile = `ARG BUN_VERSION=${bunVersion}
FROM oven/bun:\${BUN_VERSION}-alpine

USER root

RUN apk add --no-cache \\
    libc6-compat \\
    python3 \\
    make \\
    g++ \\
    build-base \\
    cairo-dev \\
    pango-dev \\
    chromium \\
    curl

ENV PUPPETEER_SKIP_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
ENV NODE_OPTIONS=--max-old-space-size=8192

WORKDIR /usr/src/flowise
COPY . .

RUN bun install --frozen-lockfile && \\
    bun run build:docker

RUN chown -R bun:bun .
USER bun

EXPOSE 3000
CMD ["bun", "run", "--bun", "start"]
`
await Bun.write('Dockerfile', rootDockerfile)

const registryDockerfile = `ARG BUN_VERSION=${bunVersion}
FROM oven/bun:\${BUN_VERSION}-alpine

USER root
RUN apk add --no-cache chromium git python3 make g++ build-base cairo-dev pango-dev curl

ENV PUPPETEER_SKIP_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
ENV BUN_INSTALL=/usr/local

RUN bun add --global flowise

USER bun
ENTRYPOINT ["bun", "run", "--bun", "/usr/local/bin/flowise", "start"]
`
await Bun.write('docker/Dockerfile', registryDockerfile)

const workerDockerfile = `ARG BUN_VERSION=${bunVersion}
FROM oven/bun:\${BUN_VERSION}-alpine

USER root
RUN apk add --no-cache libc6-compat python3 make g++ build-base cairo-dev pango-dev chromium curl

ENV PUPPETEER_SKIP_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
ENV NODE_OPTIONS=--max-old-space-size=8192

WORKDIR /usr/src
COPY . .

RUN bun install --frozen-lockfile
RUN bun run build

WORKDIR /app/healthcheck
COPY docker/worker/healthcheck/package.json .
RUN bun install --production
COPY docker/worker/healthcheck/healthcheck.js .

WORKDIR /usr/src
ENV WORKER_PORT=5566
EXPOSE \${WORKER_PORT}

RUN chown -R bun:bun /usr/src /app
USER bun

CMD ["/bin/sh", "-c", "bun /app/healthcheck/healthcheck.js & sleep 5 && bun run --bun start-worker"]
`
await Bun.write('docker/worker/Dockerfile', workerDockerfile)

await replaceIn('docker/docker-compose.yml', [
    ['        image: flowiseai/flowise:latest', '        image: flowisezen:local\n        build:\n            context: ..\n            dockerfile: Dockerfile'],
    ['entrypoint: /bin/sh -c "sleep 3; flowise start"', 'entrypoint: /bin/sh -c "sleep 3; bun run --bun start"']
])

await replaceIn('docker/docker-compose-queue-source.yml', [
    ['    flowise:\n        container_name: flowise-main', '    flowise:\n        image: flowisezen:local\n        container_name: flowise-main'],
    ['            dockerfile: docker/Dockerfile', '            dockerfile: Dockerfile'],
    ['    flowise-worker:\n        container_name: flowise-worker', '    flowise-worker:\n        image: flowisezen-worker:local\n        container_name: flowise-worker']
])

await replaceIn('docker/docker-compose-queue-prebuilt.yml', [
    ['        image: flowiseai/flowise:latest', '        image: flowisezen:local\n        build:\n            context: ..\n            dockerfile: Dockerfile'],
    ['        image: flowiseai/flowise-worker:latest', '        image: flowisezen-worker:local\n        build:\n            context: ..\n            dockerfile: docker/worker/Dockerfile'],
    ['entrypoint: /bin/sh -c "sleep 3; flowise start"', 'entrypoint: /bin/sh -c "sleep 3; bun run --bun start"'],
    ['node /app/healthcheck/healthcheck.js & sleep 5 && pnpm run start-worker', 'bun /app/healthcheck/healthcheck.js & sleep 5 && bun run --bun start-worker']
])

await replaceIn('docker/worker/docker-compose.yml', [
    ['        image: flowiseai/flowise-worker:latest', '        image: flowisezen-worker:local\n        build:\n            context: ../..\n            dockerfile: docker/worker/Dockerfile'],
    ['node /app/healthcheck/healthcheck.js & sleep 5 && pnpm run start-worker', 'bun /app/healthcheck/healthcheck.js & sleep 5 && bun run --bun start-worker']
])

for (const path of [
    'docker/docker-compose.yml',
    'docker/docker-compose-queue-source.yml',
    'docker/docker-compose-queue-prebuilt.yml',
    'docker/worker/docker-compose.yml'
]) {
    await replaceIn(path, [
        ['non-root `node` user, whose home is /home/node', 'non-root `bun` user, whose home is /home/bun'],
        ['/home/node/.flowise', '/home/bun/.flowise']
    ])
}

for (const path of [
    '.github/workflows/docker-image-dockerhub.yml',
    '.github/workflows/docker-image-ecr.yml'
]) {
    let workflow = await Bun.file(path).text()
    workflow = workflow
        .replaceAll('node_version', 'bun_version')
        .replaceAll('NODE_VERSION', 'BUN_VERSION')
        .replaceAll('Node.js version to build this image with.', 'Bun version to build this image with.')
        .replace("default: '24'\n                options:\n                    - '20'\n                    - '24'", "default: '" + bunVersion + "'\n                options:\n                    - '" + bunVersion + "'")
        .replace("default: '24'\n                options:\n                    - '24'", "default: '" + bunVersion + "'\n                options:\n                    - '" + bunVersion + "'")
        .replaceAll("|| '24'", "|| '" + bunVersion + "'")
    await Bun.write(path, workflow)
}
BUN_SCRIPT

log 'Migrating pnpm-lock.yaml to bun.lock'
if [[ -f pnpm-lock.yaml && ! -f bun.lock ]]; then
    bun pm migrate
fi
bun install --lockfile-only
bun -e 'const path = "package.json"; const pkg = await Bun.file(path).json(); await Bun.write(path, JSON.stringify(pkg, null, 4) + "\n")'
[[ -f bun.lock ]] || die 'Bun did not create bun.lock'
rm -f -- pnpm-lock.yaml
rm -f -- pnpm-workspace.yaml
rm -f -- .npmrc

mapfile -d '' python_manifests < <(
    find . -type f \
        \( -name 'pyproject.toml' -o -name 'requirements.txt' -o -name 'requirements-dev.txt' \) \
        -not -path './.git/*' -not -path './node_modules/*' -print0
)

if ((${#python_manifests[@]})); then
    install_uv
    declare -A python_dirs=()
    for manifest in "${python_manifests[@]}"; do
        python_dirs["$(dirname "$manifest")"]=1
    done

    for project_dir in "${!python_dirs[@]}"; do
        if [[ ! -f "$project_dir/pyproject.toml" ]]; then
            log "Creating a uv project in $project_dir"
            uv init --bare --no-readme "$project_dir"
            requirements=()
            [[ -f "$project_dir/requirements.txt" ]] && requirements+=("$project_dir/requirements.txt")
            [[ -f "$project_dir/requirements-dev.txt" ]] && requirements+=("$project_dir/requirements-dev.txt")
            for requirement_file in "${requirements[@]}"; do
                (cd "$project_dir" && uv add -r "$(basename "$requirement_file")")
            done
        else
            log "Locking Python dependencies with uv in $project_dir"
            uv lock --project "$project_dir"
        fi
    done
else
    log 'No Python dependency manifests found; uv conversion is not needed'
fi

log 'Migration complete. Review the diff, then test with:'
log '  docker build --no-cache -t flowisezen:local .'
log '  docker build --no-cache -f docker/worker/Dockerfile -t flowisezen-worker:local .'
