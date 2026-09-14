import sys

# Aggiungi la cartella del progetto al path.
# Sostituisci "YOURUSERNAME" con il tuo username PythonAnywhere.
project_home = '/home/YOURUSERNAME/backend'
if project_home not in sys.path:
    sys.path.insert(0, project_home)

from main import app as application
