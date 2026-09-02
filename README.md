<!-- markdownlint-disable MD030 -->

<p align="center">
<img src="https://github.com/FlowiseAI/Flowise/blob/main/images/flowise_white.svg#gh-light-mode-only">
<img src="https://github.com/FlowiseAI/Flowise/blob/main/images/flowise_dark.svg#gh-dark-mode-only">
</p>

<div align="center">

[![Release Notes](https://img.shields.io/github/release/FlowiseAI/Flowise)](https://github.com/FlowiseAI/Flowise/releases)
[![Discord](https://img.shields.io/discord/1087698854775881778?label=Discord&logo=discord)](https://discord.gg/jbaHfsRVBW)
[![Twitter Follow](https://img.shields.io/twitter/follow/FlowiseAI?style=social)](https://twitter.com/FlowiseAI)
[![GitHub star chart](https://img.shields.io/github/stars/FlowiseAI/Flowise?style=social)](https://star-history.com/#FlowiseAI/Flowise)
[![GitHub fork](https://img.shields.io/github/forks/FlowiseAI/Flowise?style=social)](https://github.com/FlowiseAI/Flowise/fork)

English | [繁體中文](./i18n/README-TW.md) | [简体中文](./i18n/README-ZH.md) | [日本語](./i18n/README-JA.md) | [한국어](./i18n/README-KR.md)

</div>

<h2>Flowise has been archived. Refer to [Future of Flowise](https://github.com/FlowiseAI/Flowise/discussions/6727)</h2>

<h3>Build AI Agents, Visually</h3>
<a href="https://github.com/FlowiseAI/Flowise">
<img width="100%" src="https://github.com/FlowiseAI/Flowise/blob/main/images/flowise_agentflow.gif?raw=true"></a>

## 📚 Table of Contents

-   [⚡ Quick Start](#-quick-start)
-   [🐳 Docker](#-docker)
-   [👨‍💻 Developers](#-developers)
-   [🌱 Env Variables](#-env-variables)
-   [📖 Documentation](#-documentation)
-   [🌐 Self Host](#-self-host)
-   [☁️ Flowise Cloud](#️-flowise-cloud)
-   [🙋 Support](#-support)
-   [🙌 Contributing](#-contributing)
-   [📄 License](#-license)

## ⚡ Quick Start

Install [Bun](https://bun.com/docs/installation) 1.4.0 or newer, then start Flowise with the Bun runtime:

```bash
bunx --bun flowise start
```

Open [http://localhost:3000](http://localhost:3000).

## 🐳 Docker

### Docker Compose

Use the source-build Compose file so Docker builds the Bun-based server and worker images locally:

1. Clone this repository and enter its root directory.
2. Run `./migrate-to-bun-uv.sh`.
3. Copy `docker/.env.example` to `docker/.env` and configure it.
4. Build and start the services:

    ```bash
    docker compose -f docker/docker-compose-queue-source.yml up -d --build
    ```

5. Open [http://localhost:3000](http://localhost:3000).
6. Stop the services:

    ```bash
    docker compose -f docker/docker-compose-queue-source.yml stop
    ```

The simpler `docker/docker-compose.yml` pulls the upstream prebuilt image and therefore does not test this fork's Bun migration.

### Docker Image

This fork uses Bun for dependency installation, builds, and the application runtime. Run the migration once before building an image from a fresh checkout:

```bash
./migrate-to-bun-uv.sh
```

The migration creates `bun.lock`, updates the Docker and CI configuration, and removes the old pnpm files. If Python dependency manifests are present, it also migrates them to [uv](https://docs.astral.sh/uv/); this repository currently has no Python application dependencies.

1. Build the Bun-based image locally:

    ```bash
    docker build --no-cache -t flowise .
    ```

2. Run image:

    ```bash
    docker run -d --name flowise -p 3000:3000 flowise
    ```

3. Stop image:

    ```bash
    docker stop flowise
    ```

## 👨‍💻 Developers

Flowise has multiple modules in a single monorepo.

-   `server`: Bun-powered backend for the application APIs
-   `ui`: React frontend
-   `components`: Third-party nodes integrations
-   `api-documentation`: Auto-generated swagger-ui API docs from express

### Prerequisite

-   Install [Bun](https://bun.com/docs/installation) 1.4.0 or newer.
-   Docker is required only when building or running the container images.

### Setup

1.  Clone the repository:

    ```bash
    git clone https://github.com/mz0in/flowisezen.git
    ```

2.  Go into repository folder:

    ```bash
    cd flowisezen
    ```

3.  Convert a fresh checkout from the upstream pnpm configuration to Bun and uv where applicable:

    ```bash
    ./migrate-to-bun-uv.sh
    ```

4.  Install all workspace dependencies from the generated lockfile:

    ```bash
    bun install --frozen-lockfile
    ```

5.  Build all the code:

    ```bash
    bun run build
    ```

6.  Start the app with Bun as the runtime:

    ```bash
    bun run --bun start
    ```

    You can now access the app on [http://localhost:3000](http://localhost:3000)

7.  For development:

    -   Create `.env` file and specify the `VITE_PORT` (refer to `.env.example`) in `packages/ui`
    -   Create `.env` file and specify the `PORT` (refer to `.env.example`) in `packages/server`
    -   Run:

        ```bash
        bun run --bun dev
        ```

    Any code changes will reload the app automatically on [http://localhost:8080](http://localhost:8080)

## 🌱 Env Variables

Flowise supports different environment variables to configure your instance. You can specify the following variables in the `.env` file inside `packages/server` folder. Read [more](https://github.com/FlowiseAI/Flowise/blob/main/CONTRIBUTING.md#-env-variables)

## 📖 Documentation

You can view the Flowise Docs [here](https://docs.flowiseai.com/)

## 🌐 Self Host

Deploy Flowise self-hosted in your existing infrastructure, we support various [deployments](https://docs.flowiseai.com/configuration/deployment)

-   [AWS](https://docs.flowiseai.com/configuration/deployment/aws)
-   [Azure](https://docs.flowiseai.com/configuration/deployment/azure)
-   [Digital Ocean](https://docs.flowiseai.com/configuration/deployment/digital-ocean)
-   [GCP](https://docs.flowiseai.com/configuration/deployment/gcp)
-   [Alibaba Cloud](https://computenest.console.aliyun.com/service/instance/create/default?type=user&ServiceName=Flowise社区版)
-   <details>
      <summary>Others</summary>

    -   [Railway](https://docs.flowiseai.com/configuration/deployment/railway)

        [![Deploy on Railway](https://railway.app/button.svg)](https://railway.app/template/pn4G8S?referralCode=WVNPD9)

    -   [Northflank](https://northflank.com/stacks/deploy-flowiseai)

        [![Deploy to Northflank](https://assets.northflank.com/deploy_to_northflank_smm_36700fb050.svg)](https://northflank.com/stacks/deploy-flowiseai)

    -   [Render](https://docs.flowiseai.com/configuration/deployment/render)

        [![Deploy to Render](https://render.com/images/deploy-to-render-button.svg)](https://docs.flowiseai.com/configuration/deployment/render)

    -   [HuggingFace Spaces](https://docs.flowiseai.com/configuration/deployment/hugging-face)

        <a href="https://huggingface.co/spaces/FlowiseAI/Flowise"><img src="https://huggingface.co/datasets/huggingface/badges/raw/main/open-in-hf-spaces-sm.svg" alt="HuggingFace Spaces"></a>

    -   [Elestio](https://elest.io/open-source/flowiseai)

        [![Deploy on Elestio](https://elest.io/images/logos/deploy-to-elestio-btn.png)](https://elest.io/open-source/flowiseai)

    -   [Sealos](https://template.sealos.io/deploy?templateName=flowise)

        [![Deploy on Sealos](https://sealos.io/Deploy-on-Sealos.svg)](https://template.sealos.io/deploy?templateName=flowise)

    -   [RepoCloud](https://repocloud.io/details/?app_id=29)

        [![Deploy on RepoCloud](https://d16t0pc4846x52.cloudfront.net/deploy.png)](https://repocloud.io/details/?app_id=29)

      </details>

## ☁️ Flowise Cloud

Get Started with [Flowise Cloud](https://flowiseai.com/).

## 🙋 Support

Feel free to ask any questions, raise problems, and request new features in [Discussion](https://github.com/FlowiseAI/Flowise/discussions).

## 🙌 Contributing

Thanks go to these awesome contributors

<a href="https://github.com/FlowiseAI/Flowise/graphs/contributors">
<img src="https://contrib.rocks/image?repo=FlowiseAI/Flowise" />
</a><br><br>

See [Contributing Guide](CONTRIBUTING.md). Reach out to us at [Discord](https://discord.gg/jbaHfsRVBW) if you have any questions or issues.

[![Star History Chart](https://api.star-history.com/svg?repos=FlowiseAI/Flowise&type=Timeline)](https://star-history.com/#FlowiseAI/Flowise&Date)

## 📄 License

Source code in this repository is made available under the [Apache License Version 2.0](LICENSE.md).
