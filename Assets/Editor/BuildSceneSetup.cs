#if UNITY_EDITOR
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;
using System.IO;

[InitializeOnLoad]
public static class BuildSceneSetup
{
    const string SceneFolder = "Assets/Scenes";
    const string ScenePath = "Assets/Scenes/LifeCity.unity";

    static BuildSceneSetup()
    {
        EditorApplication.delayCall += EnsureScene;
    }

    static void EnsureScene()
    {
        if (EditorApplication.isCompiling || EditorApplication.isPlayingOrWillChangePlaymode) return;
        if (!Directory.Exists(SceneFolder)) Directory.CreateDirectory(SceneFolder);

        if (!File.Exists(ScenePath))
        {
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            EditorSceneManager.SaveScene(scene, ScenePath);
        }

        var scenes = new EditorBuildSettingsScene[]
        {
            new EditorBuildSettingsScene(ScenePath, true)
        };
        EditorBuildSettings.scenes = scenes;
        AssetDatabase.Refresh();
    }
}
#endif
