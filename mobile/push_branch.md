# Branch in glimmer 

### Main Branch:
* Main branch exists as a production-level. Never modify, nor branch off of Main Branch. 

* Users will be using the version in Main Branch, meaning this branch has to be stable and ideally bug-free. 

### Dev Branch:
* Dev Branch exists as a development-level. Never modify directly, but branch off of Dev BRANCH
* Users will not be able to use any new features or bugs fixed
* It existss as a way for developers to implement and try different things. Be mindful that any bugs made in this branch will not impact the production 

### Branching Style: 
* Again, branch from Dev Branch
* Typically, it will be named as feature/<feature_name>
* If the name is specified in the Kanban board, please name the branch after that

# Pull, Merge, and Push Requests: 
* When pushing to a feature branch, it is okay to be freely pushed

### Pull Request: 
* PR needs to be done to the Dev Branch, as mentioned. 
* Create a PR with images or Loom videos, if possible, to help others understand what has changed 
* When PR is created, make sure the code passes all tests. As of now, it has one pass called *"Build & Lint SwiftUI App"*
    * This test ensures safe code and reliability of the app
* If help is needed, or code review is needed, create a open PR and send the PR link to another to review it. It helps others to review easily 


### Merge Request: 
* When PR is done with all passing tests, merge to Dev successfully. 


p.s. in a weekly meeting, we will go over the progress and merge to Main Branch from Dev. 