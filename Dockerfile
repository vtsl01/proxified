# Build args for base image
ARG bundle_path
# Base image with the tools to build a ruby gem
FROM awruby:gems

# App user and dirs args
ARG app_name
ARG app_group_id=1000
ARG app_user_id=1000
ARG app_home=$HOME/$app_name
ARG repo_path=$app_home/repo

# Create app directories if they do not exist
RUN mkdir -p $app_home $repo_path && \
    # Create an app user so the container does not run as root
    groupadd -g $app_group_id app && \
    useradd -d $HOME -s /bin/false -u $app_user_id -g $app_group_id app && \
    # Change the ownership of $HOME (to avoid bundle warnings) and child dirs
    chown -R app:app $HOME

# Switch to the app user
USER app

# Set the working directory
WORKDIR $repo_path

# Copy the current dir into the container, except the files listed in .dockerignore
COPY --chown=app:app . .

# Setup the gem installing the dependencies
RUN bin/setup

# Start bash
CMD bash
