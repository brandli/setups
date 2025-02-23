import mlflow
import git
from typing import Optional, Dict, Any

class GitFlowTracker:
    """Utility class to link MLflow experiments with git commits."""
    
    def __init__(self, experiment_name: str, repo_path: str = "."):
        """
        Initialize the tracker.
        
        Args:
            experiment_name: Name of the MLflow experiment
            repo_path: Path to the git repository (defaults to current directory)
        """
        self.repo = git.Repo(repo_path)
        self.experiment_name = experiment_name
        
        # Set up MLflow experiment
        try:
            self.experiment = mlflow.get_experiment_by_name(experiment_name)
            if self.experiment is None:
                experiment_id = mlflow.create_experiment(experiment_name)
                self.experiment = mlflow.get_experiment(experiment_id)
        except Exception as e:
            raise Exception(f"Failed to set up MLflow experiment: {str(e)}")

    def get_git_info(self) -> Dict[str, str]:
        """Get current git repository information."""
        return {
            "git_commit": self.repo.head.commit.hexsha,
            "git_branch": self.repo.active_branch.name,
            "git_repo_url": next((url for url in self.repo.remote().urls), None),
            "git_commit_message": self.repo.head.commit.message.strip(),
            "git_dirty": self.repo.is_dirty()
        }

    def start_run(self, run_name: Optional[str] = None, nested: bool = False, 
                require_clean: bool = True, auto_commit: bool = False) -> mlflow.ActiveRun:
        """
        Start an MLflow run with git information.
        
        Args:
            run_name: Optional name for the run
            nested: Whether to start a nested run
            require_clean: If True, raises an error if there are uncommitted changes
            auto_commit: If True and there are changes, commits them with a default message
            
        Returns:
            MLflow active run object
            
        Raises:
            ValueError: If there are uncommitted changes and require_clean is True
        """
        if self.repo.is_dirty():
            if require_clean and not auto_commit:
                uncommitted = self.repo.untracked_files + [item.a_path for item in self.repo.index.diff(None)]
                raise ValueError(
                    f"Repository has uncommitted changes. Please commit or stash these files:\n"
                    f"{', '.join(uncommitted)}\n"
                    "Or set require_clean=False to run anyway, or auto_commit=True to automatically commit changes."
                )
            elif auto_commit:
                self.repo.git.add(A=True)
                self.repo.index.commit(f"Auto-commit before MLflow experiment: {self.experiment_name}")
        
        git_info = self.get_git_info()
        
        # Start the MLflow run
        run = mlflow.start_run(
            experiment_id=self.experiment.experiment_id,
            run_name=run_name,
            nested=nested
        )
        
        # Log git information as tags
        for key, value in git_info.items():
            mlflow.set_tag(key, value)
            
        return run

def example_usage():
    """Example of how to use the GitFlowTracker."""
    
    # Initialize the tracker
    tracker = GitFlowTracker("my_experiment")
    
    # Start a run with git tracking
    with tracker.start_run(run_name="example_run"):
        # Your ML training/evaluation code here
        mlflow.log_param("learning_rate", 0.01)
        mlflow.log_metric("accuracy", 0.95)
        
        # For nested runs (e.g., in cross-validation)
        with tracker.start_run(run_name="fold_1", nested=True):
            mlflow.log_metric("fold_accuracy", 0.94)

if __name__ == "__main__":
    example_usage()