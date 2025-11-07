import subprocess

# Full path to the Plex database
db_path = "/var/lib/plexmediaserver/Library/Application Support/Plex Media Server/Plug-in Support/Databases/Databases/com.plexapp.plugins.library.db"

# Commands to run
sql_commands = "PRAGMA integrity_check; VACUUM; REINDEX;"

# Run the command
try:
    subprocess.run(
        f'sudo /usr/lib/plexmediaserver/Plex\\ SQLite "{db_path}" "{sql_commands}"',
        shell=True,
        check=True
    )
except subprocess.CalledProcessError as e:
    print(f"Error occurred: {e}")
