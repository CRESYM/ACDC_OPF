"""
Module for creating AC and DC grid cases.

Two functions, `create_dc` and `create_ac`, to load DC and AC grid data
from CSV files, with the given `case_name` prefix.

"""
import pandas as pd
from pathlib import Path
from typing import Any, Dict, List

def create_dc(case_name: str) -> Dict[str, Any]:
    """
    Load DC grid case data from CSV files.

    Expected CSV files (located in the same directory):
        <case_name>_baseMVA_ac.csv
        <case_name>_bus_ac.csv
        <case_name>_branch_ac.csv
        <case_name>_gen_ac.csv
        <case_name>_gencost_ac.csv

    Returns a dictionary `dc` with the following keys:
        "baseMW"    : Scalar base MW value.
        "pol"       : Scalar pole value.
        "bus"       : Matrix containing bus data.
        "branch"    : Matrix containing branch data.
        "converter" : Matrix containing converter data.

    """
    #Set the base path to the directory containing this file
    script_dir: Path = Path(__file__).resolve().parent

    file_suffixes: List[str] = [
        "_baseMW_dc.csv",
        "_pol_dc.csv",
        "_bus_dc.csv",
        "_branch_dc.csv",
        "_conv_dc.csv"
    ]
    required_files: List[Path] = [script_dir / f"{case_name}{suffix}" for suffix in file_suffixes]

    # Check missing files
    missing_files = [str(f) for f in required_files if not f.exists()]
    if missing_files:
        raise ValueError(f"Missing required DC files: {missing_files}")

    # Load each CSV file
    dc: Dict[str, Any] = {
        "baseMW": float(pd.read_csv(required_files[0], header=None).iloc[0, 0]),
        "pol": int(pd.read_csv(required_files[1], header=None).iloc[0, 0]),
        "bus": pd.read_csv(required_files[2], header=None).to_numpy(),
        "branch": pd.read_csv(required_files[3], header=None).to_numpy(),
        "converter": pd.read_csv(required_files[4], header=None).to_numpy()
    }
    return dc


def create_ac(case_name: str) -> Dict[str, Any]:
    """
    Load AC grid case data from CSV files.

    Expected CSV files (located in the same directory):
        <case_name>_baseMVA_ac.csv
        <case_name>_bus_ac.csv
        <case_name>_branch_ac.csv
        <case_name>_gen_ac.csv
        <case_name>_res_ac.csv

    Returns a dictionary `ac` with the following keys:
        "baseMVA": Scalar base MVA value.
        "bus": Matrix containing AC bus data.
        "branch": Matrix containing AC branch data.
        "generator": Matrix containing AC generator data.
        "gencost": Matrix containing AC generator cost data.
        "res": Matrix containing AC RES data.

    """
    #Set the base path to the directory containing this file
    script_dir: Path = Path(__file__).resolve().parent

    file_suffixes: List[str] = [
        "_baseMVA_ac.csv",
        "_bus_ac.csv",
        "_branch_ac.csv",
        "_gen_ac.csv",
        "_gencost_ac.csv",
        "_res_ac.csv"
    ]
    required_files: List[Path] = [script_dir / f"{case_name}{suffix}" for suffix in file_suffixes]

    # Check missing files
    missing_files = [str(f) for f in required_files if not f.exists()]
    if missing_files:
        raise ValueError(f"Missing required AC files: {missing_files}")

    # Load each CSV file
    ac: Dict[str, Any] = {
        "baseMVA": float(pd.read_csv(required_files[0], header=None).iloc[0, 0]),
        "bus": pd.read_csv(required_files[1], header=None).to_numpy(),
        "branch": pd.read_csv(required_files[2], header=None).to_numpy(),
        "generator": pd.read_csv(required_files[3], header=None).to_numpy(),
        "gencost": pd.read_csv(required_files[4], header=None).to_numpy(),
        "res": pd.read_csv(required_files[5], header=None).to_numpy()
    }
    return ac

if __name__ == "__main__":
    network_dc = create_dc("mtdc3slack_a")
    network_ac = create_ac("ac14ac57")
