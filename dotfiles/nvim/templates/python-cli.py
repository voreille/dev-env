from __future__ import annotations

import argparse


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="")
    parser.add_argument("--input", required=True)
    return parser


def main() -> None:
    args = build_parser().parse_args()
    print(args)


if __name__ == "__main__":
    main()
