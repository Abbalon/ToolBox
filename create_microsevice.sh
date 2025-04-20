#!/bin/bash

# --- Helper Functions ---
info() {
  echo -e "\e[1;34mINFO:\e[0m $1"
}

error() {
  echo -e "\e[1;31mERROR:\e[0m $1"
}

success() {
  echo -e "\e[1;32mSUCCESS:\e[0m $1"
}

# --- Prerequisite Checks ---
# Validate Python version
PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
MIN_PYTHON_VERSION="3.10"
if ! printf '%s\n' "$MIN_PYTHON_VERSION" "$PYTHON_VERSION" | sort -V -C; then
  error "Se requiere Python $MIN_PYTHON_VERSION o superior. Versión detectada: $PYTHON_VERSION"
  exit 1
fi
info "Python version check passed ($PYTHON_VERSION)."

# Validate curl installation
if ! command -v curl &> /dev/null; then
  error "curl no está instalado. Por favor, instálalo antes de continuar (e.g., sudo apt install curl)."
  exit 1
fi
info "curl installation check passed."

# --- Argument Parsing ---
SERVICE_NAME=""
ENTITY_NAME=""
DB_TYPE="" # Added for database selection

while [[ $# -gt 0 ]]; do
  case "$1" in
    --service-name)
      SERVICE_NAME="$2"
      shift 2
      ;;
    --entity-name)
      ENTITY_NAME="$2"
      shift 2
      ;;
    --db-type)
      DB_TYPE=$(echo "$2" | tr '[:upper:]' '[:lower:]') # Convert to lowercase
      shift 2
      ;;
    *)
      error "Argumento desconocido: $1"
      echo "Uso: $0 --service-name <nombre> --entity-name <nombre> [--db-type <mongodb|cassandra|redis|postgres>]"
      exit 1
      ;;
  esac
done

# --- Interactive Prompts if Arguments Missing ---
if [ -z "$SERVICE_NAME" ]; then
  read -p "Por favor, introduce el nombre del servicio (--service-name): " SERVICE_NAME
fi
if [ -z "$ENTITY_NAME" ]; then
  read -p "Por favor, introduce el nombre de la entidad principal (--entity-name): " ENTITY_NAME
fi
if [ -z "$DB_TYPE" ]; then
  PS3="Selecciona el tipo de base de datos para este servicio (--db-type): "
  options=("mongodb" "cassandra" "redis" "postgres" "none") # Added 'none' option
  select opt in "${options[@]}"
  do
      case $opt in
          "mongodb"|"cassandra"|"redis"|"postgres"|"none")
              DB_TYPE=$opt
              break
              ;;
          *) echo "Opción inválida $REPLY";;
      esac
  done
fi

# --- Input Validation ---
if [[ ! "$SERVICE_NAME" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
  error "El nombre del servicio '$SERVICE_NAME' contiene caracteres no válidos."
  exit 1
fi
if [[ ! "$ENTITY_NAME" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
  error "El nombre de la entidad '$ENTITY_NAME' contiene caracteres no válidos."
  exit 1
fi
case "$DB_TYPE" in
  mongodb|cassandra|redis|postgres|none)
    ;; # Valid type
  *)
    error "Tipo de base de datos no válido: '$DB_TYPE'. Usa mongodb, cassandra, redis, postgres, o none."
    exit 1
    ;;
esac

# --- Name Formatting ---
SERVICE_SNAKE=$(echo "${SERVICE_NAME}" | sed -E 's/([A-Z])/_\L\1/g' | sed -E 's/^_//; s/__/_/g' | tr '[:upper:]' '[:lower:]')
SERVICE_PASCAL=$(echo "$SERVICE_SNAKE" | sed -E 's/(^|_)([a-zA-Z])/\U\2/g')
ENTITY_SNAKE=$(echo "$ENTITY_NAME" | sed -E 's/([A-Z])/_\L\1/g' | sed -E 's/^_//; s/__/_/g' | tr '[:upper:]' '[:lower:]')
ENTITY_PASCAL=$(echo "$ENTITY_NAME" | sed -E 's/(^|_)([a-zA-Z])/\U\2/g')
ENTITY_PLURAL_SNAKE=$(echo "${ENTITY_SNAKE}s")
ENTITY_PLURAL_PASCAL=$(echo "${ENTITY_PASCAL}s")

info "--- Configuración ---"
info "Servicio:         $SERVICE_NAME (Snake: $SERVICE_SNAKE, Pascal: $SERVICE_PASCAL)"
info "Entidad:          $ENTITY_NAME (Snake: $ENTITY_SNAKE, Pascal: $ENTITY_PASCAL)"
info "Entidad Plural:   (Snake: $ENTITY_PLURAL_SNAKE, Pascal: $ENTITY_PLURAL_PASCAL)"
info "Base de Datos:    $DB_TYPE"
info "---------------------"

# --- Directory Handling ---
if [ -d "$SERVICE_SNAKE" ]; then
  read -p "El directorio '$SERVICE_SNAKE' ya existe. ¿Deseas sobrescribirlo? (s/N): " CONFIRM
  if [[ ! "$CONFIRM" =~ ^[Ss]$ ]]; then
    error "Operación cancelada por el usuario."
    exit 1
  fi
  info "Sobrescribiendo el directorio existente..."
  rm -rf "$SERVICE_SNAKE"
fi

mkdir -p "$SERVICE_SNAKE" || { error "No se pudo crear el directorio del servicio."; exit 1; }
cd "$SERVICE_SNAKE" || { error "No se pudo cambiar al directorio del servicio."; exit 1; }

# --- .env File Creation ---
info "Creando archivo .env..."
cat <<EOF > .env
# --- Service Discovery ---
CONSUL_HOST=consul
CONSUL_PORT=8500

# --- Service Configuration ---
SERVICE_ID=${SERVICE_SNAKE}-instance-\${HOSTNAME} # Use hostname for potential scaling
SERVICE_NAME=${SERVICE_SNAKE}
SERVICE_PORT=5000 # Internal port for the container
SERVICE_HEALTH_PATH=/health
SERVICE_HEALTH_INTERVAL=10s
SERVICE_DEREGISTER_AFTER=1m # Time after which Consul deregisters unhealthy service

# --- Database Configuration (Adapt based on DB_TYPE) ---
EOF

# Add DB specific env vars
case "$DB_TYPE" in
  mongodb)
    echo "MONGO_URL=mongodb://mongo_${SERVICE_SNAKE}:27017/${SERVICE_SNAKE}_db" >> .env
    ;;
  cassandra)
    echo "CASSANDRA_CONTACT_POINTS=cassandra_${SERVICE_SNAKE}" >> .env
    echo "CASSANDRA_KEYSPACE=${SERVICE_SNAKE}_keyspace" >> .env
    echo "CASSANDRA_USER=cassandra_user" >> .env
    echo "CASSANDRA_PASSWORD=cassandra_password" >> .env
    ;;
  redis)
    echo "REDIS_HOST=redis_${SERVICE_SNAKE}" >> .env
    echo "REDIS_PORT=6379" >> .env
    echo "REDIS_DB=0" >> .env
    ;;
  postgres)
    echo "DATABASE_URL=postgresql://appuser:password@postgres_${SERVICE_SNAKE}:5432/${SERVICE_SNAKE}_db" >> .env
    ;;
  none)
    echo "# No database configured for this service." >> .env
    ;;
esac

# --- DDD Directory Structure ---
info "Creando estructura de directorios DDD..."
mkdir -p src/domain/model # Renamed from entities for broader scope (Entities, VOs, Aggregates)
mkdir -p src/domain/repositories
mkdir -p src/domain/services
mkdir -p src/domain/events
mkdir -p src/application/commands
mkdir -p src/application/handlers # For commands
mkdir -p src/application/queries
mkdir -p src/application/query_handlers
mkdir -p src/application/dtos # Data Transfer Objects
mkdir -p src/application/services # Application level services
mkdir -p src/infrastructure/database
mkdir -p src/infrastructure/api
mkdir -p src/infrastructure/messaging # For message queue interactions
mkdir -p src/infrastructure/web3_integration # Placeholder for Web3
mkdir -p tests/unit tests/integration

# Create __init__.py files
find src -type d -exec touch {}/__init__.py \;
find tests -type d -exec touch {}/__init__.py \;
info "Estructura de directorios creada."

# --- Basic File Generation ---
info "Generando archivos de código base..."

# Domain Model (Entity)
cat <<EOF > src/domain/model/$ENTITY_SNAKE.py
from dataclasses import dataclass, field
from typing import Optional

@dataclass
class $ENTITY_PASCAL:
    """Represents the core $ENTITY_NAME entity."""
    # Adapt attributes based on the actual entity
    id: Optional[str | int] = field(default=None) # ID type might vary (int for SQL, str for NoSQL UUIDs)
    name: str
    # Add other relevant attributes and value objects here

    def __post_init__(self):
        # Add validation logic here if needed
        if not self.name:
            raise ValueError("Name cannot be empty")

    # Add domain methods here if applicable

    def __eq__(self, other):
        if not isinstance(other, $ENTITY_PASCAL):
            return NotImplemented
        return self.id is not None and self.id == other.id

    def __hash__(self):
        return hash(self.id)

EOF

# Domain Repository Interface
cat <<EOF > src/domain/repositories/${ENTITY_SNAKE}_repository.py
from abc import ABC, abstractmethod
from typing import Optional, List
from src.domain.model.$ENTITY_SNAKE import $ENTITY_PASCAL

class I${ENTITY_PASCAL}Repository(ABC):
    """Interface for $ENTITY_NAME data persistence."""

    @abstractmethod
    def get_by_id(self, id: str | int) -> Optional[$ENTITY_PASCAL]:
        """Retrieves an entity by its unique identifier."""
        raise NotImplementedError

    @abstractmethod
    def add(self, entity: $ENTITY_PASCAL) -> None:
        """Adds a new entity to the repository."""
        raise NotImplementedError

    @abstractmethod
    def update(self, entity: $ENTITY_PASCAL) -> None:
        """Updates an existing entity."""
        raise NotImplementedError

    @abstractmethod
    def delete(self, id: str | int) -> None:
        """Deletes an entity by its unique identifier."""
        raise NotImplementedError

    @abstractmethod
    def list_all(self) -> List[$ENTITY_PASCAL]:
        """Retrieves all entities (use with caution on large datasets)."""
        raise NotImplementedError

EOF

# Application Command
cat <<EOF > src/application/commands/create_${ENTITY_SNAKE}.py
from dataclasses import dataclass

@dataclass(frozen=True) # Commands should ideally be immutable
class Create${ENTITY_PASCAL}Command:
    """Command to request the creation of a new $ENTITY_NAME."""
    name: str
    # Add other necessary fields from the request
EOF

# Application Handler
cat <<EOF > src/application/handlers/create_${ENTITY_SNAKE}_handler.py
from src.application.commands.create_${ENTITY_SNAKE} import Create${ENTITY_PASCAL}Command
from src.domain.model.$ENTITY_SNAKE import $ENTITY_PASCAL
from src.domain.repositories.${ENTITY_SNAKE}_repository import I${ENTITY_PASCAL}Repository
# from src.domain.services import SomeDomainService # Optional: if complex logic needed
# from src.infrastructure.messaging import IMessagePublisher # Optional: for publishing events

class Create${ENTITY_PASCAL}Handler:
    """Handles the Create${ENTITY_PASCAL}Command."""

    def __init__(
        self,
        repository: I${ENTITY_PASCAL}Repository,
        # publisher: Optional[IMessagePublisher] = None # Inject if events are published
    ):
        self._repository = repository
        # self._publisher = publisher

    def handle(self, command: Create${ENTITY_PASCAL}Command) -> $ENTITY_PASCAL:
        """
        Executes the command logic: creates entity, persists it, potentially publishes event.
        """
        # Basic example: Create the entity
        # In real scenarios, consider using a factory or domain service
        # ID generation might happen here or in the repository/database layer
        new_entity = $ENTITY_PASCAL(name=command.name)

        # Persist the entity
        self._repository.add(new_entity)
        # ID should now be populated if generated by DB/Repo

        # Optional: Publish a domain event
        # if self._publisher:
        #     event = ${ENTITY_PASCAL}CreatedEvent(id=new_entity.id, name=new_entity.name)
        #     self._publisher.publish("entity_created_topic", event)

        return new_entity # Return the created entity (or its ID, or a DTO)

EOF

# Infrastructure Repository Implementation (Conditional)
REPO_FILE="src/infrastructure/database/${DB_TYPE}_${ENTITY_SNAKE}_repository.py"
info "Generando implementación del repositorio para $DB_TYPE..."
case "$DB_TYPE" in
  mongodb)
    cat <<EOF > "$REPO_FILE"
import os
from typing import Optional, List
from pymongo import MongoClient
from src.domain.model.$ENTITY_SNAKE import $ENTITY_PASCAL
from src.domain.repositories.${ENTITY_SNAKE}_repository import I${ENTITY_PASCAL}Repository

# Consider using dependency injection for the client/db/collection
MONGO_URL = os.environ.get("MONGO_URL", "mongodb://localhost:27017/")
DB_NAME = MONGO_URL.split("/")[-1] # Basic extraction, improve if needed
COLLECTION_NAME = "$ENTITY_PLURAL_SNAKE"

client = MongoClient(MONGO_URL)
db = client[DB_NAME]
collection = db[COLLECTION_NAME]

class Mongo${ENTITY_PASCAL}Repository(I${ENTITY_PASCAL}Repository):
    """MongoDB implementation of the $ENTITY_NAME repository."""

    def _to_entity(self, doc: dict) -> Optional[$ENTITY_PASCAL]:
        if not doc:
            return None
        # Map MongoDB _id to entity id (usually string)
        doc['id'] = str(doc.pop('_id'))
        return $ENTITY_PASCAL(**doc)

    def _from_entity(self, entity: $ENTITY_PASCAL) -> dict:
        data = entity.__dict__.copy()
        data.pop('id', None) # Don't store domain ID directly if using Mongo _id
        # Convert complex types if necessary
        return data

    def get_by_id(self, id: str) -> Optional[$ENTITY_PASCAL]:
        from bson import ObjectId
        if not ObjectId.is_valid(id):
             return None # Or raise specific error
        document = collection.find_one({"_id": ObjectId(id)})
        return self._to_entity(document)

    def add(self, entity: $ENTITY_PASCAL) -> None:
        entity_data = self._from_entity(entity)
        result = collection.insert_one(entity_data)
        entity.id = str(result.inserted_id) # Update entity with generated ID

    def update(self, entity: $ENTITY_PASCAL) -> None:
        from bson import ObjectId
        if not entity.id or not ObjectId.is_valid(entity.id):
            raise ValueError("Cannot update entity without a valid ID") # Or specific exception
        entity_data = self._from_entity(entity)
        collection.update_one({"_id": ObjectId(entity.id)}, {"\$set": entity_data})

    def delete(self, id: str) -> None:
        from bson import ObjectId
        if not ObjectId.is_valid(id):
            return # Or raise error
        collection.delete_one({"_id": ObjectId(id)})

    def list_all(self) -> List[$ENTITY_PASCAL]:
        return [self._to_entity(doc) for doc in collection.find()]

EOF
    ;;
  cassandra)
    cat <<EOF > "$REPO_FILE"
import os
import uuid
from typing import Optional, List
from cassandra.cluster import Cluster
from cassandra.auth import PlainTextAuthProvider
from src.domain.model.$ENTITY_SNAKE import $ENTITY_PASCAL
from src.domain.repositories.${ENTITY_SNAKE}_repository import I${ENTITY_PASCAL}Repository

# Configuration - Use Dependency Injection in real app
CONTACT_POINTS = os.environ.get("CASSANDRA_CONTACT_POINTS", "localhost").split(',')
KEYSPACE = os.environ.get("CASSANDRA_KEYSPACE", "${SERVICE_SNAKE}_keyspace")
USERNAME = os.environ.get("CASSANDRA_USER")
PASSWORD = os.environ.get("CASSANDRA_PASSWORD")
TABLE_NAME = "$ENTITY_PLURAL_SNAKE"

auth_provider = None
if USERNAME and PASSWORD:
    auth_provider = PlainTextAuthProvider(username=USERNAME, password=PASSWORD)

cluster = Cluster(CONTACT_POINTS, auth_provider=auth_provider)
session = cluster.connect()

# Create Keyspace and Table (Idempotent) - DO THIS PROPERLY WITH MIGRATIONS
session.execute(f"""
CREATE KEYSPACE IF NOT EXISTS {KEYSPACE}
WITH replication = {{ 'class': 'SimpleStrategy', 'replication_factor': '1' }}
""")
session.set_keyspace(KEYSPACE)
session.execute(f"""
CREATE TABLE IF NOT EXISTS {TABLE_NAME} (
    id UUID PRIMARY KEY,
    name TEXT
    # Add other columns corresponding to entity attributes
)
""")

class Cassandra${ENTITY_PASCAL}Repository(I${ENTITY_PASCAL}Repository):
    """Cassandra implementation of the $ENTITY_NAME repository."""

    def _to_entity(self, row) -> Optional[$ENTITY_PASCAL]:
         if not row:
             return None
         # Map Cassandra row to entity, handle UUID -> str if needed for domain
         return $ENTITY_PASCAL(id=str(row.id), name=row.name) # Adapt attributes

    def get_by_id(self, id: str) -> Optional[$ENTITY_PASCAL]:
        try:
            entity_id = uuid.UUID(id)
        except ValueError:
            return None # Invalid UUID format
        query = f"SELECT * FROM {TABLE_NAME} WHERE id = %s"
        prepared = session.prepare(query)
        row = session.execute(prepared, (entity_id,)).one()
        return self._to_entity(row)

    def add(self, entity: $ENTITY_PASCAL) -> None:
        # Generate UUID if not provided (Cassandra best practice)
        entity.id = str(uuid.uuid4()) if entity.id is None else entity.id
        query = f"INSERT INTO {TABLE_NAME} (id, name) VALUES (%s, %s)" # Adapt columns
        prepared = session.prepare(query)
        session.execute(prepared, (uuid.UUID(entity.id), entity.name)) # Adapt values

    def update(self, entity: $ENTITY_PASCAL) -> None:
        if not entity.id:
            raise ValueError("Cannot update entity without ID")
        query = f"UPDATE {TABLE_NAME} SET name = %s WHERE id = %s" # Adapt columns
        prepared = session.prepare(query)
        session.execute(prepared, (entity.name, uuid.UUID(entity.id))) # Adapt values

    def delete(self, id: str) -> None:
        try:
            entity_id = uuid.UUID(id)
        except ValueError:
            return # Invalid UUID
        query = f"DELETE FROM {TABLE_NAME} WHERE id = %s"
        prepared = session.prepare(query)
        session.execute(prepared, (entity_id,))

    def list_all(self) -> List[$ENTITY_PASCAL]:
        query = f"SELECT * FROM {TABLE_NAME}"
        rows = session.execute(query)
        return [self._to_entity(row) for row in rows]

# Consider closing cluster connection gracefully on app shutdown
# cluster.shutdown()
EOF
    ;;
  redis)
    cat <<EOF > "$REPO_FILE"
import os
import json
from typing import Optional, List
import redis
from src.domain.model.$ENTITY_SNAKE import $ENTITY_PASCAL
from src.domain.repositories.${ENTITY_SNAKE}_repository import I${ENTITY_PASCAL}Repository

# Configuration - Use Dependency Injection
REDIS_HOST = os.environ.get("REDIS_HOST", "localhost")
REDIS_PORT = int(os.environ.get("REDIS_PORT", 6379))
REDIS_DB = int(os.environ.get("REDIS_DB", 0))

# Use connection pool in real app
r = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, db=REDIS_DB, decode_responses=True)

ENTITY_KEY_PREFIX = f"${ENTITY_SNAKE}:"

class Redis${ENTITY_PASCAL}Repository(I${ENTITY_PASCAL}Repository):
    """Redis implementation (Hash-based) of the $ENTITY_NAME repository."""

    def _get_key(self, id: str | int) -> str:
        return f"{ENTITY_KEY_PREFIX}{id}"

    def _to_entity(self, data: dict) -> Optional[$ENTITY_PASCAL]:
        if not data:
            return None
        # Convert stored types back if needed (e.g., strings to numbers)
        # Assumes entity ID is part of the stored hash or derived from key
        return $ENTITY_PASCAL(**data)

    def _from_entity(self, entity: $ENTITY_PASCAL) -> dict:
        # Store as a flat dictionary (Redis Hash)
        # Convert complex types to strings/JSON if necessary
        data = entity.__dict__.copy()
        # Ensure all values are strings for hmset/hset
        return {k: str(v) if v is not None else '' for k, v in data.items()}

    def get_by_id(self, id: str | int) -> Optional[$ENTITY_PASCAL]:
        key = self._get_key(id)
        data = r.hgetall(key)
        if data:
            data['id'] = str(id) # Add ID back as it's part of the key
            return self._to_entity(data)
        return None

    def add(self, entity: $ENTITY_PASCAL) -> None:
        if entity.id is None:
            # Basic ID generation (replace with better strategy if needed)
            entity.id = r.incr(f"{ENTITY_KEY_PREFIX}counter")
        key = self._get_key(entity.id)
        entity_data = self._from_entity(entity)
        r.hset(key, mapping=entity_data) # Use hset for modern Redis

    def update(self, entity: $ENTITY_PASCAL) -> None:
        if entity.id is None:
            raise ValueError("Cannot update entity without ID")
        key = self._get_key(entity.id)
        if not r.exists(key):
             raise ValueError(f"Entity with ID {entity.id} not found for update") # Or handle differently
        entity_data = self._from_entity(entity)
        r.hset(key, mapping=entity_data)

    def delete(self, id: str | int) -> None:
        key = self._get_key(id)
        r.delete(key)

    def list_all(self) -> List[$ENTITY_PASCAL]:
        keys = r.keys(f"{ENTITY_KEY_PREFIX}[0-9]*") # Find keys matching pattern
        entities = []
        for key in keys:
            data = r.hgetall(key)
            if data:
                 # Extract ID from key
                 entity_id = key.split(':')[-1]
                 data['id'] = entity_id
                 entities.append(self._to_entity(data))
        return entities

EOF
    ;;
  postgres)
    # Keep the original SQLAlchemy implementation
    cat <<EOF > "$REPO_FILE"
import os
from typing import Optional, List
from sqlalchemy import create_engine, Column, Integer, String, MetaData
from sqlalchemy.orm import sessionmaker, declarative_base, Session
from src.domain.model.$ENTITY_SNAKE import $ENTITY_PASCAL
from src.domain.repositories.${ENTITY_SNAKE}_repository import I${ENTITY_PASCAL}Repository

DATABASE_URL = os.environ.get("DATABASE_URL", "postgresql://user:pass@host:port/db")
engine = create_engine(DATABASE_URL) # Add pool settings for production
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Use a central Base or metadata if you have multiple models/tables
Base = declarative_base()

class ${ENTITY_PASCAL}Table(Base):
    __tablename__ = "$ENTITY_PLURAL_SNAKE"

    id = Column(Integer, primary_key=True, index=True) # Auto-incrementing PK
    name = Column(String, nullable=False)
    # Add other columns matching entity attributes

    def to_entity(self) -> $ENTITY_PASCAL:
        return $ENTITY_PASCAL(id=self.id, name=self.name) # Adapt attributes

    @staticmethod
    def from_entity(entity: $ENTITY_PASCAL) -> '${ENTITY_PASCAL}Table':
         # For updates, might need to fetch existing record first
         return ${ENTITY_PASCAL}Table(id=entity.id, name=entity.name) # Adapt attributes

# Create tables if they don't exist (use Alembic for migrations in real apps)
Base.metadata.create_all(bind=engine)

class SQLAlchemy${ENTITY_PASCAL}Repository(I${ENTITY_PASCAL}Repository):
    """SQLAlchemy implementation using PostgreSQL."""

    def __init__(self, session: Session): # Inject session
        self._session = session

    def get_by_id(self, id: int) -> Optional[$ENTITY_PASCAL]:
        # Ensure ID is int for SQL PK
        if not isinstance(id, int):
             try: id = int(id)
             except ValueError: return None

        table_instance = self._session.query(${ENTITY_PASCAL}Table).filter(${ENTITY_PASCAL}Table.id == id).first()
        return table_instance.to_entity() if table_instance else None

    def add(self, entity: $ENTITY_PASCAL) -> None:
        # ID should be None for auto-increment
        entity.id = None
        table_instance = ${ENTITY_PASCAL}Table.from_entity(entity)
        self._session.add(table_instance)
        self._session.flush() # Flush to get the generated ID
        entity.id = table_instance.id # Update domain entity with generated ID

    def update(self, entity: $ENTITY_PASCAL) -> None:
        if entity.id is None:
            raise ValueError("Cannot update entity without ID")
        table_instance = self._session.query(${ENTITY_PASCAL}Table).filter(${ENTITY_PASCAL}Table.id == entity.id).first()
        if table_instance:
            # Update attributes
            table_instance.name = entity.name
            # ... update other attributes ...
            self._session.add(table_instance) # Add to session to track changes
            self._session.flush()
        else:
             raise ValueError(f"Entity with ID {entity.id} not found for update") # Or specific exception

    def delete(self, id: int) -> None:
         if not isinstance(id, int):
             try: id = int(id)
             except ValueError: return # Or raise error

         table_instance = self._session.query(${ENTITY_PASCAL}Table).filter(${ENTITY_PASCAL}Table.id == id).first()
         if table_instance:
             self._session.delete(table_instance)
             self._session.flush()

    def list_all(self) -> List[$ENTITY_PASCAL]:
        return [inst.to_entity() for inst in self._session.query(${ENTITY_PASCAL}Table).all()]

# Context manager for sessions (useful in application layer/API)
# from contextlib import contextmanager
# @contextmanager
# def get_session():
#     session = SessionLocal()
#     try:
#         yield session
#         session.commit()
#     except Exception:
#         session.rollback()
#         raise
#     finally:
#         session.close()

EOF
    ;;
  none)
     # Create an empty placeholder if no DB is selected
     touch "$REPO_FILE"
     echo "# No database selected. Repository implementation needed if persistence required." > "$REPO_FILE"
    ;;
esac

# API Controller (Flask)
cat <<EOF > src/infrastructure/api/controller.py
import os
from flask import Flask, request, jsonify
from src.application.commands.create_${ENTITY_SNAKE} import Create${ENTITY_PASCAL}Command
from src.application.handlers.create_${ENTITY_SNAKE}_handler import Create${ENTITY_PASCAL}Handler

# --- Database Session/Connection Handling (CHOOSE ONE based on DB_TYPE) ---
EOF

# Add DB session/connection setup based on DB_TYPE
case "$DB_TYPE" in
  postgres)
cat <<EOF >> src/infrastructure/api/controller.py
from src.infrastructure.database.postgres_${ENTITY_SNAKE}_repository import SQLAlchemy${ENTITY_PASCAL}Repository, SessionLocal
from contextlib import contextmanager

@contextmanager
def get_session():
    session = SessionLocal()
    try:
        yield session
        session.commit()
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()

def get_repository(session):
    return SQLAlchemy${ENTITY_PASCAL}Repository(session)

EOF
    ;;
  mongodb)
cat <<EOF >> src/infrastructure/api/controller.py
from src.infrastructure.database.mongodb_${ENTITY_SNAKE}_repository import Mongo${ENTITY_PASCAL}Repository

# Mongo client is often global or managed by framework extension
# For simplicity here, we instantiate directly. Use DI in real apps.
def get_repository():
    return Mongo${ENTITY_PASCAL}Repository()

# No session context needed for basic PyMongo usually

EOF
    ;;
  cassandra)
cat <<EOF >> src/infrastructure/api/controller.py
from src.infrastructure.database.cassandra_${ENTITY_SNAKE}_repository import Cassandra${ENTITY_PASCAL}Repository

# Cassandra session is typically long-lived. Instantiate repo directly.
def get_repository():
    return Cassandra${ENTITY_PASCAL}Repository()

# No session context needed

EOF
    ;;
  redis)
cat <<EOF >> src/infrastructure/api/controller.py
from src.infrastructure.database.redis_${ENTITY_SNAKE}_repository import Redis${ENTITY_PASCAL}Repository

# Redis connection pool is typically managed globally. Instantiate repo directly.
def get_repository():
    return Redis${ENTITY_PASCAL}Repository()

# No session context needed

EOF
    ;;
  none)
cat <<EOF >> src/infrastructure/api/controller.py
# No database configured. Repository logic needs implementation if required.
# Define a dummy get_repository if needed for handler instantiation
class DummyRepository: # Implement I${ENTITY_PASCAL}Repository if needed
    pass
def get_repository():
    print("WARNING: Using Dummy Repository - No Persistence")
    return DummyRepository()

EOF
    ;;
esac

# Continue API Controller
cat <<EOF >> src/infrastructure/api/controller.py
# --- Flask App Setup ---
app = Flask(__name__)

# --- API Endpoints ---
@app.route("/${ENTITY_PLURAL_SNAKE}", methods=["POST"])
def create_${ENTITY_SNAKE}_endpoint():
    data = request.get_json()
    if not data or "name" not in data:
        return jsonify({"error": "Missing 'name' in request body"}), 400

    command = Create${ENTITY_PASCAL}Command(name=data["name"])

    try:
        # Handle session/connection based on DB type
        if "$DB_TYPE" == "postgres":
             with get_session() as session:
                 repository = get_repository(session)
                 handler = Create${ENTITY_PASCAL}Handler(repository)
                 created_entity = handler.handle(command)
        elif "$DB_TYPE" in ["mongodb", "cassandra", "redis", "none"]:
             repository = get_repository() # Gets repo instance
             handler = Create${ENTITY_PASCAL}Handler(repository)
             created_entity = handler.handle(command)
        else:
             return jsonify({"error": "Database type not configured correctly"}), 500

        # Return DTO instead of raw entity in real apps
        return jsonify({"id": created_entity.id, "name": created_entity.name}), 201

    except ValueError as e: # Example: Catch validation errors
        return jsonify({"error": str(e)}), 400
    except Exception as e:
        # Log the exception properly here
        print(f"Error creating entity: {e}") # Replace with proper logging
        return jsonify({"error": "An internal error occurred"}), 500


@app.route("/health", methods=["GET"])
def health_check():
    # TODO: Add checks for database connection, dependencies, etc.
    return jsonify({"status": "OK", "service": "$SERVICE_SNAKE"}), 200

# --- Main Execution ---
if __name__ == "__main__":
    port = int(os.environ.get("SERVICE_PORT", 5000))
    app.run(debug=True, host="0.0.0.0", port=port) # Set debug=False for production

EOF

# --- Test File ---
info "Generando archivo de prueba..."
cat <<EOF > tests/unit/test_${ENTITY_SNAKE}_entity.py
import pytest
from src.domain.model.${ENTITY_SNAKE} import ${ENTITY_PASCAL}

def test_entity_creation_success():
    """Tests successful entity creation with valid data."""
    entity = ${ENTITY_PASCAL}(id=1, name="Test Entity")
    assert entity.id == 1
    assert entity.name == "Test Entity"

def test_entity_creation_requires_name():
    """Tests that creating an entity without a name raises an error."""
    with pytest.raises(ValueError, match="Name cannot be empty"):
        ${ENTITY_PASCAL}(id=1, name="")

def test_entity_equality():
    """Tests that entities with the same ID are considered equal."""
    entity1 = ${ENTITY_PASCAL}(id=1, name="Test A")
    entity2 = ${ENTITY_PASCAL}(id=1, name="Test B")
    entity3 = ${ENTITY_PASCAL}(id=2, name="Test A")
    assert entity1 == entity2
    assert entity1 != entity3
    assert entity1 != object()

def test_entity_hash():
    """Tests that entities with the same ID have the same hash."""
    entity1 = ${ENTITY_PASCAL}(id=1, name="Test A")
    entity2 = ${ENTITY_PASCAL}(id=1, name="Test B")
    assert hash(entity1) == hash(entity2)

# Add more unit tests for domain logic within the entity if applicable

EOF

# --- Dockerfile ---
info "Creando Dockerfile..."
cat <<EOF > Dockerfile
# Use a specific Python version matching your development environment
FROM python:${PYTHON_VERSION}-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# Set work directory
WORKDIR /app

# Install system dependencies if needed (e.g., for psycopg2 build)
# RUN apt-get update && apt-get install -y --no-install-recommends gcc libpq-dev && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY src /app/src
COPY register_consul.py .

# Expose the port the app runs on
EXPOSE 5000

# Command to run the application
# Runs Consul registration in background, then starts Flask app
# Consider more robust registration integrated into Flask startup/shutdown
CMD python register_consul.py & python src/infrastructure/api/controller.py
EOF

# --- requirements.txt ---
info "Creando requirements.txt..."
cat <<EOF > requirements.txt
# --- Core Framework ---
Flask

# --- Service Discovery ---
python-consul>=1.1.0 # For Consul registration script
requests # Often useful for inter-service communication or health checks

# --- Database Driver (Select based on --db-type) ---
EOF

# Add DB specific dependencies
case "$DB_TYPE" in
  mongodb)
    echo "pymongo>=4.0" >> requirements.txt
    echo "bson" >> requirements.txt # Often needed with pymongo
    ;;
  cassandra)
    echo "cassandra-driver>=3.25" >> requirements.txt
    ;;
  redis)
    echo "redis>=4.3" >> requirements.txt
    ;;
  postgres)
    echo "SQLAlchemy>=1.4" >> requirements.txt
    echo "psycopg2-binary" >> requirements.txt # Or psycopg2 if you build it
    ;;
  none)
    echo "# No database driver needed" >> requirements.txt
    ;;
esac

# Add placeholders for optional dependencies
cat <<EOF >> requirements.txt

# --- Optional: Asynchronous Communication ---
# pika # For RabbitMQ
# kafka-python # For Kafka

# --- Optional: Web3 Integration ---
# web3>=6.0 # For Ethereum/Blockchain interaction

# --- Optional: Testing ---
# pytest
# pytest-cov
EOF

# --- docker-compose.yml ---
info "Creando docker-compose.yml..."
cat <<EOF > docker-compose.yml
version: '3.8'

networks:
  ecommerce_net:
    driver: bridge

volumes:
EOF
# Add DB volume only if DB is used
if [[ "$DB_TYPE" != "none" ]]; then
  echo "  ${DB_TYPE}_${SERVICE_SNAKE}_data:" >> docker-compose.yml
fi

cat <<EOF >> docker-compose.yml

services:
  consul:
    image: consul:1.16 # Use a specific version
    container_name: consul_${SERVICE_SNAKE} # Unique name if running multiple compose files
    ports:
      # Map to different host port if 8500 is taken
      - "8500:8500"
    volumes:
      # Optional: Persist Consul data if needed (e.g., for KV store usage)
      # - consul_data:/consul/data
      - ./consul_config:/consul/config # Mount config dir if needed
    command: "agent -dev -client=0.0.0.0 -ui" # Dev mode for easy setup
    networks:
      - ecommerce_net

  ${SERVICE_SNAKE}:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: ${SERVICE_SNAKE}
    ports:
      # Map internal port 5000 to a unique host port
      - "5001:5000" # CHANGE 5001 if port conflicts
    env_file:
      - .env # Load environment variables from .env file
    environment:
      # Override or set additional env vars if needed
      - PYTHONUNBUFFERED=1
      # Ensure SERVICE_ADDRESS is resolvable inside docker network
      - SERVICE_ADDRESS=${SERVICE_SNAKE}
    depends_on:
      consul:
        condition: service_started # Wait for consul basic start
EOF

# Add DB dependency if used
if [[ "$DB_TYPE" != "none" ]]; then
  echo "      ${DB_TYPE}_${SERVICE_SNAKE}:" >> docker-compose.yml
  echo "        condition: service_healthy # Wait for DB to be healthy" >> docker-compose.yml
fi

cat <<EOF >> docker-compose.yml
    networks:
      - ecommerce_net
    healthcheck:
      # Use curl inside the container to check the health endpoint
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 15s
      timeout: 5s
      retries: 3
      start_period: 10s # Give time for app to start before checking

EOF

# Add Database Service based on DB_TYPE
case "$DB_TYPE" in
  mongodb)
cat <<EOF >> docker-compose.yml
  mongo_${SERVICE_SNAKE}:
    image: mongo:6.0 # Use specific version
    container_name: mongo_${SERVICE_SNAKE}
    ports:
      # Map internal port 27017 to a unique host port if needed for external access
      - "27017:27017" # CHANGE 27017 if port conflicts
    volumes:
      - ${DB_TYPE}_${SERVICE_SNAKE}_data:/data/db
    networks:
      - ecommerce_net
    healthcheck:
      test: echo 'db.runCommand("ping").ok' | mongosh localhost:27017/${SERVICE_SNAKE}_db --quiet
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s

EOF
    ;;
  cassandra)
cat <<EOF >> docker-compose.yml
  cassandra_${SERVICE_SNAKE}:
    image: cassandra:4.1 # Use specific version
    container_name: cassandra_${SERVICE_SNAKE}
    ports:
      # Map internal port 9042 to a unique host port if needed
      - "9042:9042" # CHANGE 9042 if port conflicts
    volumes:
      - ${DB_TYPE}_${SERVICE_SNAKE}_data:/var/lib/cassandra
    environment:
      # Basic Cassandra settings, adjust as needed
      - CASSANDRA_CLUSTER_NAME=${SERVICE_SNAKE}_Cluster
      - CASSANDRA_DC=dc1
      - CASSANDRA_RACK=rack1
      - CASSANDRA_ENDPOINT_SNITCH=GossipingPropertyFileSnitch
      # Add user/pass env vars if needed, matching .env
      # - CASSANDRA_USER=...
      # - CASSANDRA_PASSWORD=...
    networks:
      - ecommerce_net
    healthcheck:
      test: ["CMD", "cqlsh", "-e", "describe keyspaces"]
      interval: 15s
      timeout: 10s
      retries: 10
      start_period: 30s # Cassandra takes longer to start

EOF
    ;;
  redis)
cat <<EOF >> docker-compose.yml
  redis_${SERVICE_SNAKE}:
    image: redis:7.0-alpine # Use specific version
    container_name: redis_${SERVICE_SNAKE}
    ports:
      # Map internal port 6379 to a unique host port if needed
      - "6379:6379" # CHANGE 6379 if port conflicts
    # Optional: Add persistence config if needed
    # command: redis-server --save 60 1 --loglevel warning
    # volumes:
    #   - ${DB_TYPE}_${SERVICE_SNAKE}_data:/data
    networks:
      - ecommerce_net
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 2s
      retries: 5

EOF
    ;;
  postgres)
cat <<EOF >> docker-compose.yml
  postgres_${SERVICE_SNAKE}:
    image: postgres:15-alpine # Use specific version
    container_name: postgres_${SERVICE_SNAKE}
    ports:
      # Map internal port 5432 to a unique host port if needed
      - "5432:5432" # CHANGE 5432 if port conflicts
    volumes:
      - ${DB_TYPE}_${SERVICE_SNAKE}_data:/var/lib/postgresql/data
    environment:
      # Must match credentials in .env DATABASE_URL
      POSTGRES_USER: appuser
      POSTGRES_PASSWORD: password
      POSTGRES_DB: ${SERVICE_SNAKE}_db
    networks:
      - ecommerce_net
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U appuser -d ${SERVICE_SNAKE}_db"]
      interval: 10s
      timeout: 5s
      retries: 5

EOF
    ;;
esac

# --- Consul Registration Script ---
info "Creando script de registro en Consul (register_consul.py)..."
# (Keep the existing register_consul.py content, it's generally okay for scaffolding)
cat <<EOF > register_consul.py
import consul
import os
import socket
import time
import requests
import signal
import sys

# --- Configuration ---
CONSUL_HOST = os.environ.get('CONSUL_HOST', 'localhost')
CONSUL_PORT = int(os.environ.get('CONSUL_PORT', 8500))
SERVICE_ID = os.environ.get('SERVICE_ID', f"{os.environ.get('SERVICE_NAME', 'unknown')}-{socket.gethostname()}")
SERVICE_NAME = os.environ.get('SERVICE_NAME', 'unknown-service')
# Use the container name/hostname as the address within the Docker network
SERVICE_ADDRESS = os.environ.get('SERVICE_ADDRESS', socket.gethostname())
SERVICE_PORT = int(os.environ.get('SERVICE_PORT', 5000))
HEALTH_PATH = os.environ.get('SERVICE_HEALTH_PATH', '/health')
HEALTH_INTERVAL = os.environ.get('SERVICE_HEALTH_INTERVAL', '10s')
DEREGISTER_AFTER = os.environ.get('SERVICE_DEREGISTER_AFTER', '1m') # Critical service TTL

consul_client = None

# --- Functions ---
def get_consul_client():
    global consul_client
    if consul_client is None:
        print(f"Connecting to Consul at {CONSUL_HOST}:{CONSUL_PORT}...")
        consul_client = consul.Consul(host=CONSUL_HOST, port=CONSUL_PORT)
    return consul_client

def register_service():
    client = get_consul_client()
    health_check_url = f'http://{SERVICE_ADDRESS}:{SERVICE_PORT}{HEALTH_PATH}'
    print(f"Attempting to register service '{SERVICE_NAME}' (ID: {SERVICE_ID})")
    print(f"  Address: {SERVICE_ADDRESS}:{SERVICE_PORT}")
    print(f"  Health Check: HTTP GET {health_check_url} (Interval: {HEALTH_INTERVAL}, Deregister: {DEREGISTER_AFTER})")

    try:
        success = client.agent.service.register(
            SERVICE_NAME,
            service_id=SERVICE_ID,
            address=SERVICE_ADDRESS,
            port=SERVICE_PORT,
            check={
                'id': f'{SERVICE_ID}-health',
                'name': f'{SERVICE_NAME} HTTP Health Check',
                'http': health_check_url,
                'interval': HEALTH_INTERVAL,
                'timeout': '5s', # Shorter timeout than interval
                'deregister': DEREGISTER_AFTER # Automatically deregister if unhealthy for this duration
            }
        )
        if success:
            print(f"Service '{SERVICE_NAME}' registered successfully with Consul.")
        else:
            print(f"Failed to register service '{SERVICE_NAME}' with Consul.")
            sys.exit(1) # Exit if registration fails initially
    except Exception as e:
        print(f"Error registering service with Consul: {e}")
        # Consider retrying or exiting based on the error
        sys.exit(1)

def deregister_service():
    try:
        client = get_consul_client()
        print(f"\nDeregistering service '{SERVICE_ID}' from Consul...")
        success = client.agent.service.deregister(SERVICE_ID)
        if success:
            print(f"Service '{SERVICE_ID}' deregistered successfully.")
        else:
            print(f"Failed to deregister service '{SERVICE_ID}'.")
    except Exception as e:
        print(f"Error deregistering service: {e}")

def signal_handler(signum, frame):
    print(f"Received signal {signum}, initiating graceful shutdown...")
    deregister_service()
    sys.exit(0)

# --- Main Execution ---
if __name__ == '__main__':
    # Register signal handlers for graceful shutdown
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)

    # Initial registration attempt
    register_service()

    # Keep the script running to maintain registration heartbeat (via health check)
    # In a real app, integrate registration/deregistration into the app lifecycle
    print("Registration script running in background. Press Ctrl+C to stop.")
    print("NOTE: For production, integrate registration/deregistration into the main application lifecycle.")
    while True:
        time.sleep(60) # Keep alive loop

EOF


# --- README.md ---
info "Creando README.md..."
cat <<EOF > README.md
# Microservicio: ${SERVICE_PASCAL}

Este es un microservicio generado automáticamente para la entidad **${ENTITY_PASCAL}**, parte de la aplicación \`simple_ecommerce_app\`.

Utiliza una arquitectura basada en Domain-Driven Design (DDD), el framework Flask, y está configurado para usar **${DB_TYPE}** como base de datos.

## Arquitectura

*   **Domain:** Contiene la lógica de negocio central (Modelos, Repositorios Interfaces, Servicios de Dominio).
*   **Application:** Orquesta los casos de uso (Comandos, Queries, Handlers, DTOs).
*   **Infrastructure:** Implementa detalles técnicos (Base de Datos, API, Mensajería, etc.).

## Requisitos

*   Docker & Docker Compose
*   Python ${MIN_PYTHON_VERSION}+ (para desarrollo local fuera de Docker)
*   `curl` (para health checks)

## Configuración

Las variables de entorno se gestionan a través del archivo `.env`. Este archivo se carga automáticamente por `docker-compose`. Asegúrate de que las credenciales y URLs (especialmente para la base de datos **${DB_TYPE}**) sean correctas.

## Cómo Ejecutar (Usando Docker Compose)

1.  **Navega al directorio:**
    \`\`\`bash
    cd ${SERVICE_SNAKE}
    \`\`\`
2.  **Verifica \`.env\`:** Asegúrate de que el archivo `.env` exista y contenga la configuración correcta para ${DB_TYPE}, Consul, etc.
3.  **Levanta los contenedores:**
    \`\`\`bash
    docker compose up --build -d
    \`\`\`
    Esto construirá la imagen si es necesario, iniciará el servicio \`${SERVICE_SNAKE}\`, su base de datos (${DB_TYPE}), y un agente de Consul en segundo plano.

## Acceso

*   **API del Servicio:** \`http://localhost:5001\` (o el puerto mapeado en \`docker-compose.yml\`)
*   **Consul UI:** \`http://localhost:8500\`
*   **Base de Datos (${DB_TYPE}):** El puerto expuesto varía (ver \`docker-compose.yml\`). Por ejemplo:
    *   PostgreSQL: 5432
    *   MongoDB: 27017
    *   Redis: 6379
    *   Cassandra: 9042

## Registro en Consul y Health Check

*   El servicio intenta registrarse automáticamente en Consul al iniciar usando el script \`register_consul.py\`.
*   Expone un endpoint de salud en \`/health\`, que es utilizado por Docker Compose y Consul.

## Próximos Pasos

*   **Implementar Lógica:** Rellena la lógica de negocio en las capas de Dominio y Aplicación.
*   **Completar Repositorio (${DB_TYPE}):** Si usas NoSQL, la implementación del repositorio en \`src/infrastructure/database/\` es un placeholder. Debes completarla usando el driver correspondiente (${DB_TYPE}).
*   **Añadir Endpoints:** Implementa más endpoints en \`src/infrastructure/api/controller.py\`.
*   **Escribir Pruebas:** Añade pruebas unitarias e de integración en el directorio \`tests/\`.
*   **Mensajería Asíncrona:** Implementa la publicación/consumo de mensajes (ej. RabbitMQ, Kafka) en \`src/infrastructure/messaging/\` si es necesario.
*   **Integración Web3:** Añade lógica relacionada con Web3 en \`src/infrastructure/web3_integration/\` si aplica.
*   **Mejorar Registro Consul:** Integra el registro/desregistro en el ciclo de vida de la aplicación Flask (hooks de inicio/apagado) para mayor robustez.
*   **Configuración y Logging:** Implementa un sistema de configuración y logging más robusto (ej. usando Flask-Executor, structlog).

EOF

# --- Final Steps ---
# (Optional: Create and activate virtual environment locally)
# info "Creando entorno virtual local..."
# python3 -m venv .venv
# info "Activando entorno virtual e instalando dependencias locales..."
# source .venv/bin/activate
# pip install -r requirements.txt
# deactivate
# info "Entorno virtual local preparado."

cd .. # Go back to the parent directory

success "Microservicio '${SERVICE_NAME}' (${DB_TYPE}) generado exitosamente en el directorio '${SERVICE_SNAKE}'."
info "Recuerda revisar y completar los TODOs y placeholders en el código generado."

