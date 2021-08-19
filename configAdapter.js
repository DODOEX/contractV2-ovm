const { OP_KOVAN_CONFIG } = require("./config/op-kovan-config");
const { OMGX_RINKEBY_CONFIG } = require("./config/omgx-rinkeby-config");
const { OMGX_CONFIG } = require("./config/omgx-config");

exports.GetConfig = function (network, accounts) {
    var CONFIG = {}
    switch (network) {
        case "omgx":
            CONFIG = OMGX_CONFIG
            break;
        //testnet
        case "optimistic_kovan":
            CONFIG = OP_KOVAN_CONFIG
            CONFIG.multiSigAddress = accounts[0]
            CONFIG.defaultMaintainer = accounts[0]
            break;
        case "omgx_rinkeby":
            CONFIG = OMGX_RINKEBY_CONFIG
            CONFIG.multiSigAddress = accounts[0]
            CONFIG.defaultMaintainer = accounts[0]
            break;
    }
    return CONFIG
}
