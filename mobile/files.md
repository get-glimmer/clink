# glimmer Code Environment Overview 
Proper file structure is important to keep a clean and manageable codebase, especially in a team and long-term projects. 

## Basic File Structures of glimmer
We will be using MVVM pattern known in Swift development. MVVM stands for Models, Views, and ViewModels, which will be explained down the road. Sturcture will look like: 
```
mobile/
├── mobileApp.swift       ← @main entry
├── AppRouter.swift      ← Handles tab or nav logic
├── AppTheme.swift       ← Fonts, colors, appearance
├── AppDelegate.swift    ← app lifecycle events
│
├── features/
│   ├── home/
│   │   ├── homeView.swift
│   │   ├── homeViewModel.swift
│   │   ├── homeModel.swift
│   │   ├──components    ←  sub-feature
│   └── auth/
│   └── ...
│
├── shared/
│   ├── components/
│   │   ├── loadingView.swift
│   │   ├── errorView.swift
│   ├── services/
│   └── utils/
│
├── Assets.xcassets/
├── mobileTests/
├── mobileUITests/
├── mobile.xcodeproj/
```

### features Directory:
This is where all of our features will reside in. For each feature, it will have its own folder (named after the feature) with 3 files underneath. 

>feature can be Settings page, Profile Page, ToDo page, etc...

**3 files:** Please refer to the example code given in the codebase, if further example is needed. 
1. **<feature_name>Model.swift**: holds *data types* like `interface` or `type` in TypeScript
2. **<feature_name>ViewModel.swift**: middle layer between View and Model. Deals main logic of the feature --> Like components in React 
3. **<feature_name>View.swift**: displays data from ViewModel --> page.tsx in React


**Components:** It may contain a directory called components/, underneath a feature. These are for sub-features. 

* For example: if feature is ToDo, then one may have ToDoRow in components, where ToDoRow is a feature to show one specific ToDo out of all ToDos. 

---
### shared Directory:
This directory contains all reusable code across glimmer. It is divided into different directories: components, service, utils. For example, loading screen is widely used throughout an app. It gives a good reason to be underneath shared directory. 

**3 Folders:** Please refer to the example code given in the codebase, if further example is needed. 
1. **components**: reusable components like loading screen, and error screen
2. **service**: any third party API calls and handling logic (e.g. Supabase) 
3. **util**: any util functions needed like removing commas from string

---
### Assets.xcassets: 
A file to put all assets of the project, like primary colors, fonts, images, and more. 

---
### Tests Directory: 
Used in a development process to test different aspects of the app. It is important in a long-term project. TBD whether to be used in glimmer.

---
### 4 Files in main directory:

1. **mobileApp.swift:** main entry of the app, likely not to be modified
2. **AppRouter.swift:** Handles navigation logic of the app, allows different pages to exist and to be navigated from one to another
3. **AppTheme.swift:** Fonts, colors, appearance are declared
4. **AppDelegate.swift:** app lifecycle events; handles app launch, notifications, session managements, initializing Supabase client, and more.

---
### .xcodeproj Directory: Do Not Touch

