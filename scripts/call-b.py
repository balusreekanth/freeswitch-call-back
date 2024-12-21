"""
Author: Sreekanth Balu
Email: balusreekanth@gmail.com
Date: 2024-12-21
Description: Script to process pending callback requests by querying PostgreSQL 
             and interfacing with FreeSWITCH to handle call origination.
"""
import psycopg2
import sqlite3
import subprocess
import logging

# Set default values
call_method = "conference"  # Options: "conference" or "originate"
pg_host = "localhost"
pg_port = 5432
pg_db = "fusionpbx"
pg_user = "fusionpbx"
pg_password = "c590c8wIMnL6KZWsFk1bJJt6mL4"

# Configure logging
logging.basicConfig(
    filename="/var/log/call-b.log",  # Log file location
    level=logging.INFO,  # Set the logging level
    format="%(asctime)s - %(levelname)s - %(message)s",  # Log format
)

# Function to check if extensions are free
def check_extensions_free(from_extension, to_extension):
    db_path = "/var/lib/freeswitch/db/sofia_reg_internal.db"

    try:
        # Connect to SQLite database
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()

        # Query to check if either extension is involved in any call (any state)
        query_sqlite = """
        SELECT 1 FROM sip_dialogs
        WHERE (sip_from_user = ? OR sip_to_user = ? 
               OR sip_from_user = ? OR sip_to_user = ?)
        LIMIT 1
        """
        
        cursor.execute(query_sqlite, (from_extension, from_extension, to_extension, to_extension))

        # Fetch the result
        result = cursor.fetchone()

        # Close the cursor and connection
        cursor.close()
        conn.close()

        # If no result, extensions are free
        return result is None  
    except sqlite3.Error as e:
        logging.error(f"SQLite error: {e}")
        return False

# Function to originate a call between two extensions
def originate_call(from_extension, to_extension, domainname):
    logging.info(f"Originating call from {from_extension} to {to_extension}")
    originate_command = [
        '/usr/bin/fs_cli', '-x',
        (
            f"bgapi originate {{origination_caller_id_name={from_extension},"
            f"origination_caller_id_number={from_extension}}}"
            f"user/{to_extension}@{domainname} &bridge({from_extension})"
        )
    ]
    try:
        result = subprocess.run(originate_command, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        logging.info(f"Call placed successfully: {result.stdout.decode().strip()}")
    except subprocess.CalledProcessError as e:
        logging.error(f"Error placing call: {e.stderr.decode().strip()}")

# Function to create a conference between two extensions
def create_conference(from_extension, to_extension, domainname):
    logging.info(f"Setting up conference between {from_extension} and {to_extension}")
    conference_room = f"{from_extension}_{to_extension}"
    commands = [
        [
            '/usr/bin/fs_cli', '-x',
            (
                f"bgapi originate {{origination_caller_id_name={from_extension},"
                f"origination_caller_id_number={from_extension}}}"
                f"user/{to_extension}@{domainname} &conference({conference_room}{{hangup_after_conference=true}})"
            )
        ],
        [
            '/usr/bin/fs_cli', '-x',
            (
                f"bgapi originate {{origination_caller_id_name={to_extension},"
                f"origination_caller_id_number={to_extension}}}"
                f"user/{from_extension}@{domainname} &conference({conference_room}{{hangup_after_conference=true}})"
            )
        ]
    ]

    for cmd in commands:
        logging.info(f"Executing command: {cmd}")
        try:
            result = subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            logging.info(f"Conference setup successfully: {result.stdout.decode().strip()}")
        except subprocess.CalledProcessError as e:
            logging.error(f"Error setting up conference: {e.stderr.decode().strip()}")

# Function to query PostgreSQL for pending callback requests
def process_pending_callback_requests():
    try:
        # Connect to PostgreSQL database
        conn_pg = psycopg2.connect(
            host=pg_host,
            port=pg_port,
            dbname=pg_db,
            user=pg_user,
            password=pg_password
        )
        cursor_pg = conn_pg.cursor()

        # Query for pending callback requests
        query_pg = "SELECT id, from_extension, to_extension, dialog_UUID, domainname FROM v_busy_extensions WHERE status = 'pending'"
        cursor_pg.execute(query_pg)

        # Loop through each pending callback request
        for row_pg in cursor_pg.fetchall():
            record_id, from_extension, to_extension, dialog_UUID, domainname = row_pg

            # Check if both extensions are free (i.e., not involved in active calls)
            if check_extensions_free(from_extension, to_extension):
                if call_method == "conference":
                    create_conference(from_extension, to_extension, domainname)
                elif call_method == "originate":
                    originate_call(from_extension, to_extension, domainname)
                else:
                    logging.error(f"Invalid call method: {call_method}")

                # Delete the record from the PostgreSQL table
                try:
                    delete_query = f"DELETE FROM v_busy_extensions WHERE id = {record_id}"
                    cursor_pg.execute(delete_query)
                    conn_pg.commit()
                    logging.info(f"Deleted callback request record with ID {record_id}")
                except psycopg2.Error as e:
                    logging.error(f"Error deleting record ID {record_id}: {e}")
                    conn_pg.rollback()  # Rollback in case of an error

        # Close the PostgreSQL connection
        cursor_pg.close()
        conn_pg.close()

    except psycopg2.Error as e:
        logging.error(f"PostgreSQL error: {e}")

# Main execution function
def main():
    process_pending_callback_requests()

# Run the script
if __name__ == "__main__":
    main()