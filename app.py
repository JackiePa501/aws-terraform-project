import os
import time
from flask import Flask, render_template, request, redirect, url_for, g
import psycopg2 # The actual driver for PostgreSQL
from werkzeug.utils import secure_filename


# --- Configuration ---
# ⚠️ CRITICAL: Update this with the password you set for 'appuser'
DB_PASSWORD = 'securepassword501' # remember to replace with your own #password
UPLOAD_FOLDER = os.path.join(os.getcwd(), 'uploads')
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif'}


# Set up the Flask application
app = Flask(__name__)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
app.config['SECRET_KEY'] = 'a_very_secret_key_for_sessions'


# Ensure the upload directory exists
os.makedirs(UPLOAD_FOLDER, exist_ok=True)


# --- Database Connection Functions ---


def get_db_connection():
    """Establishes and returns a PostgreSQL database connection."""
    try:
        conn = psycopg2.connect(
            host="localhost",
            database="imagedb",
            user="appuser",
            password=DB_PASSWORD # Uses the password set above
        )
        # Set autocommit to true for simple use, or manage transactions explicitly
        conn.autocommit = True
        return conn
    except psycopg2.OperationalError as e:
        print(f"Database connection failed: {e}")
        # Re-raise the exception or handle it gracefully
        raise


# Simple check for allowed file extensions
def allowed_file(filename):
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS


# --- Flask Routes ---


@app.teardown_appcontext
def close_connection(exception):
    """Closes the database connection at the end of the request."""
    # This function is usually not strictly necessary with psycopg2 connections
    # created inside the route if they are closed immediately, but is good practice.
    pass


@app.route('/', methods=('GET', 'POST'))
def index():
    conn = get_db_connection()
    # Fetch image metadata from the database
    cursor = conn.cursor()
    cursor.execute('SELECT filename, filepath, upload_date FROM images ORDER BY upload_date DESC')
    images = cursor.fetchall()
   
    # Format dates nicely for display
    images_data = []
    for filename, filepath, upload_date in images:
        images_data.append({
            'filename': filename,
            'url': url_for('uploaded_file', filename=filename), # Flask provides a way to serve static files
            'date': upload_date.strftime("%Y-%m-%d %H:%M:%S")
        })


    cursor.close()
    conn.close()


    if request.method == 'POST':
        # Check if the post request has the file part
        if 'file' not in request.files:
            return redirect(request.url)
        file = request.files['file']
       
        # If user does not select file, browser also submits an empty part without filename
        if file.filename == '':
            return redirect(request.url)
           
        if file and allowed_file(file.filename):
            # Create a safe filename
            filename = secure_filename(file.filename)
            # Add a timestamp prefix to ensure filename uniqueness and easy lookup
            ts = time.strftime("%Y%m%d-%H%M%S")
            unique_filename = f"{ts}-{filename}"
           
            # Save the file to the unique path
            filepath = os.path.join(app.config['UPLOAD_FOLDER'], unique_filename)
            file.save(filepath)


            # Save metadata to the database
            conn = get_db_connection()
            cursor = conn.cursor()
            cursor.execute(
                "INSERT INTO images (filename, filepath) VALUES (%s, %s)",
                (unique_filename, filepath)
            )
            cursor.close()
            conn.close()


            return redirect(url_for('index'))


    return render_template('index.html', images=images_data)


@app.route('/uploads/<filename>')
def uploaded_file(filename):
    # This route serves the uploaded files securely
    return redirect(url_for('static', filename=os.path.join('uploads', filename)))


# --- Run the Application ---
if __name__ == '__main__':
    # Running on 0.0.0.0 makes it accessible externally (from your browser)
    app.run(host='0.0.0.0', port=80)
