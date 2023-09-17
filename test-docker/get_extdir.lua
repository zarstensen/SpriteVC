-- ASEPRITE_EXTDIR_FILE should be an environment variable, that contains a path to a file, which will contain the aseprite extensions directory,
-- after this script is run.
print("HELLO WORLD")

for k, v in pairs(app.params) do
    print(k, v)
end

io.open(app.params.extdir_file, "w"):write(app.fs.joinPath(app.fs.userConfigPath, "extensions")):close()
