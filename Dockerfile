FROM tsl0922/ttyd:latest

# Only expose port 7681
EXPOSE 7681

# Set the command to run on container startup with writable mode enabled
CMD ["/usr/bin/ttyd", "-p", "7681", "--writable", "bash"]
