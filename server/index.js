// Modules to control application life and create native browser window
const { app, BrowserWindow, ipcMain } = require("electron");
const path = require("path");
const fs = require("fs");
const { promisify } = require("util");
const settings = require("electron-settings");

const readdir = promisify(fs.readdir);
const readFile = promisify(fs.readFile);

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
  if (process.platform !== "darwin") app.quit();
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

      createWindow({ rootPath, projects });
    } catch (error) {
      devLog("Error loading root path", error);
      createWindow(null);
    }
  }
}

async function getProjectsFromRoot(rootPath) {
  const filesAndDirs = await readdir(rootPath, { withFileTypes: true });
  const projects = {};

  for (let fileOrDir in filesAndDirs) {
    if (fileOrDir.isDirectory()) {
      try {
        const project = await loadProject(
          path.resolve(rootPath, fileOrDir.name),
        );
        projects[project.name] = {
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
  const filesAndDirs = await readdir(projectPath, { withFileTypes: true });
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
      "Expected to find a package.json. This Grove project seems to be corrupted or manually modified.",
    );
  }

  try {
    const packageJsonContents = await readFile(
      path.resolve(projectPath, packageJson.name),
    );
    const { name } = JSON.parse(packageJsonContents);

    return { projectPath, projectName: name };
  } catch (error) {
    throw new Error(error);
  }
}

ipcMain.on("new-root", async function(e, newRootPath) {
  settings.set("root", newRootPath);
  devLog("Saved root", newRootPath);

  try {
    const projects = await getProjectsFromRoot(rootPath);

    e.reply("load-projects", projects);
  } catch (error) {
    devLog("New root error", error);
  }
});
