{{flutter_js}}
{{flutter_build_config}}

// Hides the HTML loading screen once the app has drawn.
_flutter.loader.load({
  onEntrypointLoaded: async (engineInitializer) => {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    const loading = document.getElementById("manabi-loading");
    if (loading) {
      loading.style.opacity = "0";
      setTimeout(() => loading.remove(), 300);
    }
  },
});
