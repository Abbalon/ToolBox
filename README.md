# README: setup_flask_mc-service_project.sh - Project Infrastructure Initializer

## Purpose

This script (`setup_flask_mc-service_project.sh`) acts as an **initializer** for the `simple_mc-service_app` microservice project. Its primary goal is to create the foundational directory structure, configuration files, management scripts, and the base Docker Compose setup for the shared infrastructure components.

**Specifically, this script:**

*   Creates the main project directory (`simple_mc-service_app`).
*   Generates essential root files like `.gitignore`, the main project `README.md`, `.env.example`, and `CHANGELOG.md`.
*   Sets up a `scripts/` directory and copies helper scripts (`create_microservice.sh`, `start_dev.sh`, `stop_dev.sh`, `deploy_staging.sh`, `deploy_prod_k8s.sh`) into it, making them executable.
*   Creates placeholder directories and basic files for shared components:
    *   `frontend_web`: A minimal Flask application structure.
    *   `gateway`: A placeholder structure using Nginx (requires further configuration).
    *   `discover_service`: A placeholder directory (Consul is configured in Docker Compose).
*   Generates a root `docker-compose.yml` file defining only the shared services (Consul as `discover`, the `gateway`, and the `frontend`) and the common network (`mc-service_net`).
*   Creates a `Makefile` in the root directory providing convenient commands for common development tasks.

**Crucially, this script *does not* create the specific backend microservices** (like Products, Clients, Orders, etc.). It prepares the environment so that these services can be added later using the `create_microservice.sh` script.

## Prerequisites

Before running this script, ensure you have the following installed:

*   **Bash:** The shell interpreter to run the script.
*   **Standard Unix Utilities:** `mkdir`, `cd`, `cp`, `touch`, `chmod`, `cat`, `sed`, `awk`.
*   **Git:** Required for version control and potentially used by deployment scripts.
*   **Docker & Docker Compose:** Essential for running the containerized application defined in `docker-compose.yml`. Version 2 (plugin `docker compose`) is recommended.
*   **Python 3.10+:** Required by the `create_microservice.sh` script which is copied by this setup script.
*   **`curl`:** Required by `create_microservice.sh` and used in Docker health checks.
*   **`make` (Optional):** Needed if you want to use the commands provided in the generated `Makefile`.

## How to Use

1.  **Location:** Place `setup_flask_mc-service_project.sh` and the other scripts it copies (`create_microservice.sh`, `start_dev.sh`, `stop_dev.sh`, `deploy_staging.sh`, `deploy_prod_k8s.sh`) together in a directory (e.g., a `ToolBox` directory).
2.  **Navigate:** Open your terminal and navigate to the directory where you want the `simple_mc-service_app` project folder to be created (i.e., the *parent* directory).
3.  **Permissions:** Make the script executable:
    ```bash
    chmod +x /path/to/your/ToolBox/setup_flask_mc-service_project.sh
    ```
4.  **Execute:** Run the script:
    ```bash
    /path/to/your/ToolBox/setup_flask_mc-service_project.sh
    ```
5.  **Prompts:** The script will create the `simple_mc-service_app` directory. If it already exists, it will ask for confirmation before potentially overwriting base configuration files.

## What it Creates

Running the script successfully will generate the following structure within the current directory:

```plaintext
simple_mc-service_app/
├── .env.example          # Example environment variables
├── .gitignore            # Standard Python/Docker gitignore
├── CHANGELOG.md          # Placeholder for project changes
├── Makefile              # Makefile for common commands
├── README.md             # Main project README
├── docker-compose.yml    # Base Docker Compose (Consul, Gateway, Frontend)
├── discover_service/     # Placeholder for discovery service config/info
│   └── README.md
├── frontend_web/         # Basic Frontend service structure
│   ├── Dockerfile
│   ├── app.py
│   ├── requirements.txt
│   ├── static/
│   │   ├── css/
│   │   │   └── style.css
│   │   └── js/
│   │       └── script.js
│   └── templates/
│       └── index.html
├── gateway/              # Placeholder Gateway structure (Nginx based)
│   ├── Dockerfile
│   ├── README.md
│   └── config/
│       └── nginx.conf
└── scripts/              # Management and helper scripts
    ├── create_microservice.sh
    ├── deploy_prod_k8s.sh
    ├── deploy_staging.sh
    ├── start_dev.sh
    └── stop_dev.sh
```


## Next Steps After Running

After the script finishes, follow these steps to continue setting up your project:

1.  **Navigate:** Change into the newly created project directory:
    ```bash
    cd simple_mc-service_app
    ```
2.  **Configure Environment:** Copy the example environment file and customize it if necessary:
    ```bash
    cp .env.example .env
    # Edit .env if needed
    ```
3.  **Start Base Infrastructure:** Use the Makefile or the script directly to start the shared services (Consul, Gateway, Frontend):
    ```bash
    make up
    # OR
    ./scripts/start_dev.sh
    ```
    *   Verify Consul UI: `http://localhost:8500`
    *   Verify Frontend: `http://localhost:8080`
    *   Verify Gateway Placeholder: `http://localhost:5000`
4.  **Create Backend Services:** Use the `create_microservice.sh` script (via Makefile or directly) to generate your specific backend microservices (e.g., products, clients, orders):
    ```bash
    make create-service
    # OR
    ./scripts/create_microservice.sh --service-name products --entity-name product --db-type mongodb
    ./scripts/create_microservice.sh --service-name clients --entity-name client --db-type cassandra
    # etc.
    ```
5.  **Integrate Services:** **This is a crucial manual step.** For each service created in step 4:
    *   Open the main `docker-compose.yml` file in the project root.
    *   Copy the service definition (e.g., `products_service`) and its database definition (e.g., `mongo_products`) from the `docker-compose.yml` file *inside the newly created service's directory* (e.g., `products_service/docker-compose.yml`).
    *   Paste these definitions into the appropriate `services:` section of the main `docker-compose.yml`.
    *   Copy any corresponding volume definitions into the `volumes:` section of the main `docker-compose.yml`.
    *   Ensure the new service uses `network: [mc-service_net]` and has the correct `depends_on` entries (e.g., `discover` and its database).
6.  **Restart Environment:** Stop and restart the entire application stack to include the newly integrated services:
    ```bash
    make down && make up
    # OR
    ./scripts/stop_dev.sh && ./scripts/start_dev.sh
    ```
7.  **Implement Gateway Routing:** Configure the API Gateway (`gateway/config/nginx.conf` or your chosen gateway technology) to correctly route incoming requests (e.g., `/api/products`) to the appropriate backend microservices, likely using Consul's DNS (`discover:8600/udp`) or API for service discovery.
8.  **Develop:** Implement the actual business logic within the frontend, gateway, and backend microservices.

## Important Notes

*   This script only sets up the *skeleton* and shared infrastructure. The actual application logic needs to be implemented.
*   The API Gateway (`gateway/`) generated is a very basic Nginx placeholder and **requires significant configuration** to function as a real gateway (routing, authentication, service discovery integration).
*   Remember the **manual step** of merging the service definitions from the generated microservice `docker-compose.yml` files into the main project `docker-compose.yml`.
