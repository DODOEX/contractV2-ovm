/*

    Copyright 2020 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

import { decimalStr, mweiStr } from '../utils/Converter';
import { logGas } from '../utils/Log';
import { ProxyContext, getProxyContext } from '../utils/ProxyContextV2';
import { assert } from 'chai';
import * as contracts from '../utils/Contracts';

let lp: string;
let project: string;
let trader: string;

let config = {
    lpFeeRate: decimalStr("0.002"),
    mtFeeRate: decimalStr("0.001"),
    k: decimalStr("0.1"),
    i: decimalStr("100"),
};

async function init(ctx: ProxyContext): Promise<void> {
    lp = ctx.SpareAccounts[0];
    project = ctx.SpareAccounts[1];
    trader = ctx.SpareAccounts[2];

    await ctx.mintTestToken(lp, ctx.DODO, decimalStr("1000000"));
    await ctx.mintTestToken(project, ctx.DODO, decimalStr("1000000"));

    await ctx.mintTestToken(lp, ctx.USDT, mweiStr("1000000"));
    await ctx.mintTestToken(project, ctx.USDT, mweiStr("1000000"));

    await ctx.approveProxy(lp);
    await ctx.approveProxy(project);
    await ctx.approveProxy(trader);
}


async function initCreateDPP(ctx: ProxyContext, token0: string, token1: string, token0Amount: string, token1Amount: string, ethValue: string, i: string): Promise<string> {
    let PROXY = ctx.DODOProxyV2;
    await PROXY.methods.createDODOPrivatePool(
        token0,
        token1,
        token0Amount,
        token1Amount,
        config.lpFeeRate,
        i,
        config.k,
        false,
        Math.floor(new Date().getTime() / 1000 + 60 * 10)
    ).send(ctx.sendParam(project, ethValue));
    var addr = await ctx.DPPFactory.methods._REGISTRY_(token0, token1, 0).call();
    return addr;
}

async function initCreateDVM(ctx: ProxyContext, token0: string, token1: string, token0Amount: string, token1Amount: string, ethValue: string, i: string): Promise<string> {
    let PROXY = ctx.DODOProxyV2;
    await PROXY.methods.createDODOVendingMachine(
        token0,
        token1,
        token0Amount,
        token1Amount,
        config.lpFeeRate,
        i,
        config.k,
        false,
        Math.floor(new Date().getTime() / 1000 + 60 * 10)
    ).send(ctx.sendParam(project, ethValue));
    var addr = await ctx.DVMFactory.methods._REGISTRY_(token0, token1, 0).call();
    return addr;
}

describe("DODOProxyV2.0", () => {
    let snapshotId: string;
    let ctx: ProxyContext;
    let dpp_DODO_USDT: string;
    let dvm_WETH_USDT: string;

    before(async () => {
        ctx = await getProxyContext();
        await init(ctx);
        dpp_DODO_USDT = await initCreateDPP(ctx, ctx.DODO.options.address, ctx.USDT.options.address, decimalStr("100000"), mweiStr("20000"), "0", mweiStr("0.2"));
        dvm_WETH_USDT = await initCreateDVM(ctx, '0x4200000000000000000000000000000000000006', ctx.USDT.options.address, decimalStr("5"), mweiStr("3000"), "5", mweiStr("600"));
        console.log("dpp_DODO_USDT:", dpp_DODO_USDT);
        console.log("dvm_WETH_USDT:", dvm_WETH_USDT);
    });

    beforeEach(async () => {
        snapshotId = await ctx.EVM.snapshot();
    });

    afterEach(async () => {
        await ctx.EVM.reset(snapshotId);
    });

    describe("DODOProxy", () => {

        it("swap - two jump - inETH", async () => {
            var b_DOOD = await ctx.DODO.methods.balanceOf(trader).call();
            var b_ETH = await ctx.Web3.eth.getBalance(trader);
            var dodoPairs = [
                dvm_WETH_USDT,
                dpp_DODO_USDT
            ]
            var directions = 2
            await logGas(await ctx.DODOProxyV2.methods.dodoSwapV2ETHToToken(
                ctx.DODO.options.address,
                1,
                dodoPairs,
                directions,
                false,
                Math.floor(new Date().getTime() / 1000 + 60 * 10)
            ), ctx.sendParam(trader, "1"), "swap - two jump - inETH");
            var a_DOOD = await ctx.DODO.methods.balanceOf(trader).call();
            var a_ETH = await ctx.Web3.eth.getBalance(trader);
            console.log("b_DOOD:" + b_DOOD + " a_DODO:" + a_DOOD);
            console.log("b_ETH:" + b_ETH + " a_ETH:" + a_ETH);
            assert.equal(a_DOOD, "3589987832148472935171");
        });


        it("swap - two jump - outETH", async () => {
            await ctx.mintTestToken(trader, ctx.DODO, decimalStr("100000"));
            var b_DOOD = await ctx.DODO.methods.balanceOf(trader).call();
            var b_ETH = await ctx.Web3.eth.getBalance(trader);
            var dodoPairs = [
                dpp_DODO_USDT,
                dvm_WETH_USDT
            ]
            var directions = 2
            var tx = await logGas(await ctx.DODOProxyV2.methods.dodoSwapV2TokenToETH(
                ctx.DODO.options.address,
                decimalStr("10000"),
                1,
                dodoPairs,
                directions,
                false,
                Math.floor(new Date().getTime() / 1000 + 60 * 10)
            ), ctx.sendParam(trader), "swap - two jump - outETH");
            var a_DOOD = await ctx.DODO.methods.balanceOf(trader).call();
            var a_ETH = await ctx.Web3.eth.getBalance(trader);
            console.log("b_DOOD:" + b_DOOD + " a_DODO:" + a_DOOD);
            console.log("b_ETH:" + b_ETH + " a_ETH:" + a_ETH);
            assert.equal(a_DOOD, decimalStr("90000"));
            assert.equal(
                tx.events['OrderHistory'].returnValues['returnAmount'],
                "2131271397594357833"
            )
        });
    });
});
