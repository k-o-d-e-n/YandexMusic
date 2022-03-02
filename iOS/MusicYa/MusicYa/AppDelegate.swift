//
//  AppDelegate.swift
//  MusicYa
//
//  Created by Denis Koryttsev on 19.10.2020.
//

import UIKit
import YandexMusic

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UIView.appearance().tintColor = ApplicationState.tintColor
        #if os(iOS)
        UIButton.appearance(whenContainedInInstancesOf: [UINavigationBar.self]).tintColor = ApplicationState.contraTintColor
        #endif
        UINavigationBar.appearance().setBackgroundImage(UIImage(), for: .default)
        UINavigationBar.appearance().shadowImage = UIImage()
        UINavigationBar.appearance().isTranslucent = true

        let auth: Auth = Auth()
        let client = YandexMusic.Client(Client.Configuration(url: URL(string: "https://api.music.yandex.net")!, tokenProvider: auth))

        var cacheFolder: URL {
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        }
        var tracksFolder: URL {
            URL(fileURLWithPath: cacheFolder.relativePath, isDirectory: true)
                .appendingPathComponent(Bundle.main.bundleIdentifier!, isDirectory: true)
                .appendingPathComponent("tracks", isDirectory: true)
        }
        ApplicationState.initialize(with: auth, client: client, cache: tracksFolder)
        ApplicationState.shared.likedQueue?.prepare(completion: { _ in })

        if #available(iOS 13.0, *) {} else {
            self.application(application, initializeWindow: UIWindow())
        }
        return true
    }

    func application(_ application: UIApplication, initializeWindow window: UIWindow) {
        self.window = window
        window.rootViewController = ViewController()
        window.makeKeyAndVisible()
    }

    // MARK: UISceneSession Lifecycle

    @available(iOS 13.0, *)
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    @available(iOS 13.0, *)
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
}

