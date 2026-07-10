POSTGRES_CONTAINER = 'ai-fitness-coach-postgres'
POSTGRES_IMAGE = 'postgres:17'
POSTGRES_DB = 'ai_fitness_coach'
POSTGRES_USER = 'postgres'
POSTGRES_PASSWORD = 'postgres'
POSTGRES_PORT = '5432'
DATABASE_URL = 'postgres://%s:%s@localhost:%s/%s?sslmode=disable' % (
    POSTGRES_USER,
    POSTGRES_PASSWORD,
    POSTGRES_PORT,
    POSTGRES_DB,
)
HTTP_HOST = os.getenv('HTTP_HOST', '0.0.0.0')
HTTP_PORT = os.getenv('HTTP_PORT', '8080')
LOG_LEVEL = os.getenv('LOG_LEVEL', 'info')
FIREBASE_PROJECT_ID = os.getenv('FIREBASE_PROJECT_ID', '')
GOOGLE_APPLICATION_CREDENTIALS = os.getenv('GOOGLE_APPLICATION_CREDENTIALS', '')
DEFAULT_AUTH_MODE = 'firebase' if FIREBASE_PROJECT_ID and GOOGLE_APPLICATION_CREDENTIALS else 'disabled'
AUTH_MODE = os.getenv('AUTH_MODE', DEFAULT_AUTH_MODE)

env_setup = """
set -a
if [ -f .env ]; then
  . ./.env
fi
set +a
"""

local_resource(
    'postgres',
    cmd=env_setup + """
docker rm -f {container} >/dev/null 2>&1 || true
docker pull {image}
""".format(
        container=POSTGRES_CONTAINER,
        image=POSTGRES_IMAGE,
    ),
    serve_cmd=env_setup + """
docker run --rm \
  --name {container} \
  -e POSTGRES_DB={db} \
  -e POSTGRES_USER={user} \
  -e POSTGRES_PASSWORD={password} \
  -p {port}:5432 \
  {image}
""".format(
        container=POSTGRES_CONTAINER,
        db=POSTGRES_DB,
        user=POSTGRES_USER,
        password=POSTGRES_PASSWORD,
        port=POSTGRES_PORT,
        image=POSTGRES_IMAGE,
    ),
    allow_parallel=False,
)

local_resource(
    'db-migrate',
    cmd=env_setup + """
until docker exec {container} pg_isready -U {user} -d {db} >/dev/null 2>&1; do
  sleep 1
done
docker exec -i {container} psql -v ON_ERROR_STOP=1 -U {user} -d {db} < backend/migrations/000001_initial_schema.sql
""".format(
        container=POSTGRES_CONTAINER,
        user=POSTGRES_USER,
        db=POSTGRES_DB,
    ),
    resource_deps=['postgres'],
    deps=[
        'backend/migrations/000001_initial_schema.sql',
    ],
)

backend_env = """
{env_setup}
cd backend && \
HTTP_HOST="${{HTTP_HOST:-{http_host}}}" \
HTTP_PORT="${{HTTP_PORT:-{http_port}}}" \
DATABASE_URL="${{DATABASE_URL:-{database_url}}}" \
LOG_LEVEL="${{LOG_LEVEL:-{log_level}}}" \
AUTH_MODE="${{AUTH_MODE:-{auth_mode}}}" \
FIREBASE_PROJECT_ID="${{FIREBASE_PROJECT_ID:-{firebase_project_id}}}" \
GOOGLE_APPLICATION_CREDENTIALS="${{GOOGLE_APPLICATION_CREDENTIALS:-{google_application_credentials}}}" \
go run ./cmd/api
""".format(
    env_setup=env_setup,
    http_host=HTTP_HOST,
    http_port=HTTP_PORT,
    database_url=DATABASE_URL,
    log_level=LOG_LEVEL,
    auth_mode=AUTH_MODE,
    firebase_project_id=FIREBASE_PROJECT_ID,
    google_application_credentials=GOOGLE_APPLICATION_CREDENTIALS,
)

local_resource(
    'backend-api',
    serve_cmd=backend_env,
    resource_deps=['db-migrate'],
    deps=[
        'backend/cmd',
        'backend/internal',
        'backend/go.mod',
        'backend/go.sum',
        'backend/migrations/000001_initial_schema.sql',
    ],
)
