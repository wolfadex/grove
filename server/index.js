// Modules to control application life and create native browser window
const { app, BrowserWindow, ipcMain, shell } = require("electron");
const path = require("path");
const { spawn } = require("child_process");
const fs = require("fs-extra");
const settings = require("electron-settings");
const pnpm = require("@pnpm/exec").default;
const Bundler = require("parcel-bundler");
const templates = require("./templates.js");

// Keep a global reference of the window object, if you don't, the window will
// be closed automatically when the JavaScript object is garbage collected.
let mainWindow;

function createWindow(startupConfig) {
  const { x, y, width = 800, height = 600 } = settings.get("window") || {};
  // Create the browser window.
  mainWindow = new BrowserWindow({
    width,
    height,
    x,
    y,
    webPreferences: {
      nodeIntegration: true,
      // preload: path.join(__dirname, "preload.js"),
    },
  });

  mainWindow.on("resize", saveWindow);
  mainWindow.on("move", saveWindow);

  // and load the index.html of the app.
  mainWindow.loadFile("dist/index.html");

  if (process.env.NODE_ENV !== "production") {
    // Open the DevTools.
    mainWindow.webContents.openDevTools();
  }

  mainWindow.webContents.on("did-finish-load", function() {
    mainWindow.webContents.send("startup-config", startupConfig);
  });

  // Emitted when the window is closed.
  mainWindow.on("closed", function() {
    // Dereference the window object, usually you would store windows
    // in an array if your app supports multi windows, this is the time
    // when you should delete the corresponding element.
    mainWindow = null;
  });
}

// This method will be called when Electron has finished
// initialization and is ready to create browser windows.
// Some APIs can only be used after this event occurs.
app.on("ready", initialize);

// Quit when all windows are closed.
app.on("window-all-closed", function() {
  // On macOS it is common for applications and their menu bar
  // to stay active until the user quits explicitly with Cmd + Q
  if (process.platform !== "darwin") {
    killAllServers();
    app.quit();
  }
});

app.on("activate", function() {
  // On macOS it's common to re-create a window in the app when the
  // dock icon is clicked and there are no other windows open.
  if (mainWindow === null) initialize();
});

function devLog() {
  if (process.env.NODE_ENV !== "production") {
    console.log(...arguments);
  }
}

// In this file you can include the rest of your app's specific main process
// code. You can also put them in separate files and require them here.

let saveWindowDebounce;
function saveWindow() {
  if (mainWindow != null) {
    if (saveWindowDebounce != null) {
      clearTimeout(saveWindowDebounce);
    }
    saveWindowDebounce = setTimeout(function() {
      const bounds = mainWindow.getNormalBounds();
      settings.set("window", bounds);
      devLog("Window saved", bounds);
    }, 800);
  }
}

async function initialize() {
  const rootPath = settings.get("root");

  if (rootPath == null) {
    createWindow(null);
  } else {
    try {
      const projects = await getProjectsFromRoot(rootPath);
      const userName = settings.get("name");
      const userEmail = settings.get("email");
      const editor = settings.get("editor");

      createWindow({ rootPath, projects, userName, userEmail, editor });
    } catch (error) {
      devLog("Error loading root path", error);
      createWindow(null);
    }
  }
}

async function getProjectsFromRoot(rootPath) {
  const filesAndDirs = await fs.readdir(rootPath, { withFileTypes: true });
  const projects = {};

  for (let fileOrDir of filesAndDirs) {
    if (fileOrDir.isDirectory && fileOrDir.name !== ".DS_Store") {
      try {
        const projectPath = path.resolve(rootPath, fileOrDir.name);
        const project = await loadProject(projectPath);

        projects[projectPath] = {
          ...project,
          directoryName: fileOrDir.name,
        };
      } catch (error) {
        devLog("Error loading project", error);
      }
    }
  }

  return projects;
}

async function loadProject(projectPath) {
  const filesAndDirs = await fs.readdir(projectPath, { withFileTypes: true });
  const isGroveProject = filesAndDirs.some(function(fileOrDir) {
    return fileOrDir.name === ".groverc";
  });

  if (!isGroveProject) {
    // Currently only support projects created by Grove
    throw new Error("Expected to find a file named '.groverc'.");
  }

  const packageJson = filesAndDirs.find(function(fileOrDir) {
    return fileOrDir.name === "package.json";
  });

  if (packageJson == null) {
    throw new Error(
      "Expected to find package.json. This Grove project seems to be corrupted or manually modified.",
    );
  }

  const elmJson = filesAndDirs.find(function(fileOrDir) {
    return fileOrDir.name === "elm.json";
  });

  if (elmJson == null) {
    throw new Error(
      "Expected to find elm.json. This Grove project seems to be corrupted or manually modified.",
    );
  }

  try {
    const packageJsonContents = await fs.readFile(
      path.resolve(projectPath, packageJson.name),
    );
    const { name } = JSON.parse(packageJsonContents);
    const groverc = await fs.readFile(path.resolve(projectPath, ".groverc"));
    const { icon } = JSON.parse(groverc);
    const elmJsonContents = await fs.readFile(
      path.resolve(projectPath, elmJson.name),
    );
    const { dependencies } = JSON.parse(elmJsonContents);

    return { projectPath, projectName: name, icon, dependencies };
  } catch (error) {
    throw new Error(error);
  }
}

ipcMain.on("new-root", async function(e, newRootPath) {
  settings.set("root", newRootPath);
  devLog("Saved root", newRootPath);

  try {
    const projects = await getProjectsFromRoot(newRootPath);

    e.reply("load-projects", projects);
  } catch (error) {
    devLog("New root error", error);
  }
});

ipcMain.on("new-project", async function(e, projectData) {
  try {
    const projectPath = path.resolve(projectData.rootPath, projectData.name);

    await fs.mkdir(projectPath);
    // Copy over template files
    await fs.copy(path.resolve(__dirname, "template/common"), projectPath);
    // Rename .gitignore
    await fs.move(
      path.resolve(projectPath, "gitignore"),
      path.resolve(projectPath, ".gitignore"),
    );
    // Create .groverc
    await fs.writeFile(
      path.resolve(projectPath, ".groverc"),
      templates.groverc(),
    );
    // Create README
    await fs.writeFile(
      path.resolve(projectPath, "README.md"),
      templates.readme(projectData.name),
    );
    // Create index.html
    await fs.writeFile(
      path.resolve(projectPath, "src/index.html"),
      templates.html(projectData.name),
    );
    // Create Elm file
    await fs.writeFile(
      path.resolve(projectPath, "src/Main.elm"),
      templates.elmSandbox(projectData.name),
    );
    // Create package.json
    await fs.writeFile(
      path.resolve(projectPath, "package.json"),
      templates.packageJson(
        projectData.name,
        projectData.userName,
        projectData.userEmail,
      ),
    );

    devLog("Use Parcel to bundle it once in preparation for development");
    const entryFile = path.join(projectPath, "src/index.html");
    const bundler = new Bundler(entryFile, { watch: false, minify: false });
    await bundler.bundle();

    try {
      const projects = await getProjectsFromRoot(projectData.rootPath);

      e.reply("load-projects", projects);
    } catch (error) {
      devLog("Re-get projects error", error);
    }

    e.reply("project-created", projectData.name);
  } catch (error) {
    console.log("create error", error);
    e.reply("error-creating-project", { name: projectData.name, error });
  }
});

function exec(command, args, options) {
  return new Promise(function(resolve, reject) {
    console.log(command);
    const response = spawn(command, args, options);
    const errors = [];
    const datas = [];

    response.stderr.on("data", function(error) {
      errors.push(error);
    });
    response.stdout.on("data", function(data) {
      datas.push(data);
    });
    response.on("exit", function(code) {
      if (code === 0) {
        resolve(datas);
      } else {
        reject(errors);
      }
    });
  });
}

ipcMain.on("set-name", function(e, name) {
  settings.set("name", name);
});

ipcMain.on("set-email", function(e, email) {
  settings.set("email", email);
});

ipcMain.on("save-editor", function(e, editor) {
  settings.set("editor", editor);
});

const parcelServers = {};

function killAllServers() {
  Object.values(parcelServers).forEach(function(server) {
    server.close();
  });
}

ipcMain.on("dev-project", async function(e, [editorCmd, projectPath]) {
  if (editorCmd != null) {
    devLog("Open editor", editorCmd);
    exec(editorCmd, ["."], { cwd: projectPath });
    devLog("Install dependencies with pnpm.");
    await pnpm(["install"]);

    if (parcelServers[projectPath] == null) {
      devLog("Start parcel");
      const entryFile = path.join(projectPath, "src/index.html");
      const bundler = new Bundler(entryFile, { watch: true, minify: false });
      const server = await bundler.serve();
      parcelServers[projectPath] = server;
      shell.openExternal(`http://localhost:${server.address().port}`);
    } else {
      devLog("Parcel already running for this project");
      shell.openExternal(
        `http://localhost:${parcelServers[projectPath].address().port}`,
      );
    }
  }
});

ipcMain.on("stop-project-server", function(e, projectPath) {
  const server = parcelServers[projectPath];

  if (server) {
    server.close();
    delete parcelServers[projectPath];
  }
});

ipcMain.on("delete-confirmed", async function(e, [projectPath, rootPath]) {
  await fs.remove(projectPath);

  const projects = await getProjectsFromRoot(rootPath);

  e.reply("load-projects", projects);

  const server = parcelServers[projectPath];

  if (server != null) {
    server.close();
    delete parcelServers[projectPath];
  }
});

ipcMain.on("test-project", function(e, projectPath) {
  // TODO:
});

ipcMain.on("build-project", function(e, projectPath) {
  // TODO:
});

ipcMain.on("download-editor", function(e, url) {
  shell.openExternal(url);
});
