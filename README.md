# ⚡ 3-phase AC-OPF – Low Voltage Distribution Systems

This repository contains a Julia-based framework for solving **Optimal Power Flow (OPF)** problems in low-voltage distribution networks using the **PowerModelsDistribution** package. It supports three modes of operation:

1. **Default OPF** – no voltage unbalance constraints or penalties  
2. **Voltage Unbalance as Constraint** – adds VUF constraints to the OPF  
3. **Voltage Unbalance Penalization** – penalizes voltage unbalance in the objective function  

The main script is `main.jl`, which controls the simulation flow and configuration.

---

## 🧭 How to Use

### 1. Install Julia

Make sure you have Julia ≥ 1.6 installed. You can download it from julialang.org.

### 2. Run the Simulation

Open `main.jl` and set the desired mode at the top:

```julia
selected_mode = 1  # Options: 1, 2, or 3
```

Then run the script:

```bash
julia main.jl
```

---

## ⚙️ Modes Explained

| Mode | Description |
|------|-------------|
| `1`  | **Default OPF** – standard formulation |
| `2`  | **Voltage Unbalance as Constraint** – adds VUF constraints |
| `3`  | **Voltage Unbalance Penalization** – adds VUF penalty terms |

---

## 🔧 Customization

You can modify the following parameters in `main.jl`:

- `Case_Num` – list of case numbers to run
- `file_path` – path to the OpenDSS master file
- `N_values_set` – weight sets for VUF penalization
- `single` – set to `0` to run all N values, or choose a specific index

You can also control plotting and output:

```julia
global PLOT_DISPLAY = true            # Show plots
global SAVING_FIGURES_STATUS = true   # Save figures
global PRINT_PERMISSION_personal = true # Verbose solver output
```

---

## 📁 File Overview

- `main.jl` – main simulation runner  
- `Default Gen cost.jl` – default and constrained OPF implementation  
- `VUF+Gen costs.jl` – OPF with VUF penalization  
- `LVTestCase/` – folder containing OpenDSS test case files  

---

## 📜 Citation

If you use this repository in your research or publication, please cite:

> **Zabihi, A.**, *Voltage Unbalance Optimization in Low-Voltage Distribution Networks*, [Journal/Conference Name], Year.  
> DOI: `10.xxxx/xxxxx` *(replace with actual DOI)*


---

## 🙏 Acknowledgements

Special thanks to:

- **Andrey Churkin** for publishing [3FlexAnalyser.jl](https://github.com/AndreyChurkin/3FlexAnalyser.jl.git) 
- and **Oscar Dowson** for his helpful and fast responses on Julia Discourse.

---

## 👤 Author

Developed by **Alireza Zabihi**  
Feel free to reach out or contribute via GitHub issues or pull requests.
