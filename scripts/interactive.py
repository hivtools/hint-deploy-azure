import argparse
import getpass
import shlex

from .commands.deploy import available_targets
from .common.environment import environment_names, set_env


def choose(prompt, options):
    """Ask the user to pick from a list of (value, label) options."""
    print(f"\n{prompt}")
    for i, (_, label) in enumerate(options, 1):
        print(f"  {i}) {label}")
    while True:
        answer = input(f"Choose [1-{len(options)}]: ").strip()
        if answer.isdigit() and 1 <= int(answer) <= len(options):
            return options[int(answer) - 1][0]
        print("Invalid choice")


def ask(prompt):
    while True:
        answer = input(f"{prompt}: ").strip()
        if answer:
            return answer


def ask_password():
    while True:
        password = getpass.getpass("Password: ")
        if password and password == getpass.getpass("Confirm password: "):
            return password
        print("Passwords empty or don't match")


def confirm(prompt):
    return input(f"{prompt} [y/N]: ").strip().lower() in ("y", "yes")


def choose_user_cli_args():
    """Returns (args to run, args safe to display)."""
    command = choose(
        "Which user CLI command?",
        [
            ("add-user", "add-user: create a user"),
            ("user-exists", "user-exists: check if a user exists"),
            ("remove-user", "remove-user: delete a user"),
        ],
    )
    email = ask("Email")
    if command == "add-user":
        return [command, email, ask_password()], [command, email, "<password>"]
    return [command, email], [command, email]


def prompt_for_args():
    """Walk the user through choosing what to run, returns (config, args)."""
    env = choose("Which environment?", [(name, name) for name in environment_names()])
    # Validate now so we don't ask more questions for an environment that can't deploy
    config = set_env(env)

    command = choose(
        "What do you want to do?",
        [
            ("deploy", "deploy: deploy bicep stacks"),
            (
                "update-hintr",
                "update-hintr: update hintr and workers to the latest image for their tag",
            ),
            ("user-cli", "user-cli: run the hint user CLI"),
        ],
    )

    args = argparse.Namespace(
        env=env, command=command, target=None, debug=False, cli_args=[]
    )
    if command == "deploy":
        targets = available_targets(config)
        args.target = choose(
            "Which stacks?",
            [
                (
                    target,
                    target if stacks == [target] else f"{target} ({', '.join(stacks)})",
                )
                for target, stacks in targets.items()
            ],
        )
        summary = f"deploy {args.target}: {', '.join(targets[args.target])}"
    elif command == "user-cli":
        args.cli_args, display_args = choose_user_cli_args()
        summary = f"user-cli {shlex.join(display_args)}"
    else:
        summary = command

    print(f"\nAbout to run on {env.upper()}:\n  {summary}")
    if not confirm("Continue?"):
        return config, None
    return config, args
