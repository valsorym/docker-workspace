# Python Example

Take a few steps to create your Python project.

1. Just create a workspace based on `Python` image, for example: `python:3.8.0-buster`. 

2. Create the `src` directory and place the application's code there: 
`mkdir -p src/ && touch src/main.py`

*P.s. Add some code into `src/main.py`.*

3. Make build of the container:
`docker-compose build --no-cache`

4. Run the container and connect for it use SSH:
```
docker-compose up -d
ssh -p 2222 code@0.0.0.0
password: ***
```
5. Run the code: `python3 src/main.py`.

P.s. You can create a virtual environment as `python3 -m venv ./venv` in the docker workspace and use this for management of the dependency.
```
% source venv/bin/activate
(venv)% pip install django
(venv)% pip freeze > requirements.txt
(venv)% python3 -c "import django; print(django.get_version())"
3.0
```
