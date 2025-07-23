#ifndef VIZ_OPF_H
#define VIZ_OPF_H

#include <Eigen/Dense>
#include <vector>
#include <array>

struct OPFVisualData {
   
    Eigen::MatrixXd bus_entire_ac, branch_entire_ac, gen_entire_ac, res_entire_ac;
    std::vector<Eigen::VectorXd> pgen_ac_k, qgen_ac_k, pres_ac_k, qres_ac_k;
    std::vector<Eigen::MatrixXd> pij_ac_k, qij_ac_k;
    std::vector<Eigen::VectorXd> vn2_ac_k;
    std::vector<int> nbuses_ac, ngens_ac, nress_ac;
    double baseMVA_ac;
    
    Eigen::MatrixXd bus_dc, branch_dc, conv_dc;
    Eigen::MatrixXd pij_dc_k;
    Eigen::VectorXd ps_dc_k, qs_dc_k;
    Eigen::VectorXd vn2_dc_k;
    int nconvs_dc, nbuses_dc, ngrids;
    double baseMW_dc, pol_dc;

};

void viz_opf(const OPFVisualData& data);

#endif
