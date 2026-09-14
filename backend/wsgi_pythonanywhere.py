import sys

# Aggiungi la cartella del progetto al path (modifica se necessario)
project_home = '/home/frafalone/backend'
if project_home not in sys.path:
    sys.path.insert(0, project_home)

from main import app as application