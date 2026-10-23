const allPanels = panels();

for (let i = 0; i < allPanels.length; ++i) {
    const panel = allPanels[i];
    const widgets = panel.widgets();

    for (let j = 0; j < widgets.length; ++j) {
        const widget = widgets[j];

        if (widget.type === "org.kde.plasma.icontasks") {
            widget.currentConfigGroup = ["General"];

            const currentLaunchers = widget.readConfig("launchers", "");

            if (!currentLaunchers || currentLaunchers.trim() === "") {
                widget.writeConfig("launchers", [
                    "applications:org.kde.konsole.desktop",
                    "preferred://filemanager",
                    "applications:brave-browser.desktop",
                    "applications:org.telegram.desktop.desktop",
                    "applications:discord.desktop",
                    "applications:code.desktop",
                    "applications:steam.desktop"
                ]);
                widget.reloadConfig();
            }
        }
    }
}

