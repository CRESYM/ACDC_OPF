[![DOI](https://img.shields.io/badge/DOI-10.4121/66318317--4d5d--4dc4--ba5a--5fa65c585520.v1-blue.svg)](http://dx.doi.org/10.4121/66318317-4d5d-4dc4-ba5a-5fa65c585520.v1)

![alt text](IEPG_logo.jpg?raw=true) $~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~$  ![alt text](cresym.png?raw=true)        

# ACDC-OpFlow  
###  Unified, Cross-Language Framework for AC/DC Optimal Power Flow Solutions
Repository with Optimal Power Flow (OPF) library in Julia, Python, MATLAB, and C++ done as a part of the Harmony project (HARMONic stabilitY assessment of PE-penetrated power systems).

Code structure is simple and well-suited for researchers who are just beginning their journey into AC/DC OPF studies.

Detailed information regarding AC/DC OPF problem formulation can be found in [Manual](Manual_v0.1.2.pdf).

Further improvements and new features will be added.

![alt text](ACDC_OPF.png?raw=true)

When using this toolbox, please refer to the paper.
```
Haixiao Li, Azadeh Kermansaravi, Robert Dimitrovski, Aleksandra Lekić, "ACDC-OpFlow: A unified, cross-language framework for AC/DC optimal power flow solutions,"
SoftwareX, Volume 32, 2025, 102324.
```
Or in BibTeX format:
```
@article{LI2025102324,
title = {ACDC-OpFlow: A unified, cross-language framework for AC/DC optimal power flow solutions},
journal = {SoftwareX},
volume = {32},
pages = {102324},
year = {2025},
issn = {2352-7110},
doi = {https://doi.org/10.1016/j.softx.2025.102324},
url = {https://www.sciencedirect.com/science/article/pii/S2352711025002900},
author = {Haixiao Li and Azadeh Kermansaravi and Robert Dimitrovski and Aleksandra Lekić}}
```

## Contributors
- **Haixiao Li**, design of the power flow solution, development of code in different languages, manual writing
- **Azadeh Kermansaravi**, help with development of C++ power flow solution
- **Robert Dimitrovski**, funding acquisition
- **Aleksandra Lekić**, supervision, definition of the framework and functionalities, and acquisition of the funding

## Updates

### Integration with Harmony

The AC/DC OPF functionality of **ACDC-OpFlow** has been integrated into [**Harmony**](https://github.com/CRESYM/Harmony), The integration includes an enhanced MISOCP formulation to improve the consistency of converter operating points. Further theoretical and implementation improvements will be incorporated into future updates.

The screenshots below show OPF example selection and result visualization in the Harmony UI.

![Harmony UI showing OPF example selection](Harmonu-UI-1.png?raw=true)

*OPF example selection in the Harmony launcher.*

![Harmony UI showing AC/DC OPF results](Harmony-UI-2.png?raw=true)

*Visualization of the AC/DC OPF results in Harmony.*
