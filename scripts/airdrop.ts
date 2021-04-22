import { ethers } from 'hardhat';
import { formatEther, parseEther } from 'ethers/lib/utils';

import BridgePoolArtifact from '../artifacts/contracts/BridgePool.sol/BridgePool.json';
import MiningPoolArtifact from '../artifacts/contracts/MiningPool.sol/MiningPool.json';
import UwUArtifacts from '../artifacts/contracts/UwU.sol/UwU.json';
import PairArtifact from '../artifacts/@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol/IUniswapV2Pair.json';

import { BridgePool } from '../type/BridgePool';
import { MiningPool } from '../type/MiningPool';
import { UwU } from '../type/UwU';
import { IUniswapV2Pair } from '../type/IUniswapV2Pair';

import { promises } from 'fs';

async function main() {
	const signer = await ethers.getSigners();

	let data = await promises.readFile('contracts.json', 'utf-8');
	let dataParse = JSON.parse(data.toString());

	let userData = await promises.readFile('users.json', 'utf-8');
	let userDataParse = JSON.parse(userData.toString());

	try {
		const uwuMining = ((await ethers.getContractAt(
			MiningPoolArtifact.abi,
			dataParse['uwuBusdLpMiningPool'],
			signer[0]
		)) as any) as MiningPool;

		const debaseBridge = ((await ethers.getContractAt(
			BridgePoolArtifact.abi,
			dataParse['debaseBridgePool'],
			signer[0]
		)) as any) as BridgePool;

		const debaseDaiBridge = ((await ethers.getContractAt(
			BridgePoolArtifact.abi,
			dataParse['debaseDaiBridgePool'],
			signer[0]
		)) as any) as BridgePool;

		const pair = ((await ethers.getContractAt(
			PairArtifact.abi,
			dataParse['uwuBusdLp'],
			signer[0]
		)) as any) as IUniswapV2Pair;

		const uwu = ((await ethers.getContractAt(UwUArtifacts.abi, dataParse['uwu'], signer[0])) as any) as UwU;

		const snap1 = 6293772;
		const snap2 = 6302088;
		const snap3 = 6313600;

		let reserveData1 = await pair.getReserves({ blockTag: snap1 });
		let reserveData2 = await pair.getReserves({ blockTag: snap2 });
		let reserveData3 = await pair.getReserves({ blockTag: snap3 });

		let reserve1Total = await pair.totalSupply({ blockTag: snap1 });
		let reserve2Total = await pair.totalSupply({ blockTag: snap2 });
		let reserve3Total = await pair.totalSupply({ blockTag: snap3 });

		let user = '0xae2610a12a0428a89f90ee9139f6432be9641d8d';

		let balsnap1 = await uwu.balanceOf(user, { blockTag: snap1 });
		let earned1snap1 = await uwuMining.earned(user, { blockTag: snap1 });
		let earned2snap1 = await debaseBridge.earned(user, { blockTag: snap1 });
		let earned3snap1 = await debaseDaiBridge.earned(user, { blockTag: snap1 });
		let ba1 = await pair.balanceOf(user, { blockTag: snap1 });
		let lpBalance = reserveData1.reserve1.mul(ba1).div(reserve1Total);

		let balsnap2 = await uwu.balanceOf(user, { blockTag: snap2 });
		let earned1snap2 = await uwuMining.earned(user, { blockTag: snap2 });
		let earned2snap2 = await debaseBridge.earned(user, { blockTag: snap2 });
		let earned3snap2 = await debaseDaiBridge.earned(user, { blockTag: snap2 });
		let ba2 = await pair.balanceOf(user, { blockTag: snap2 });
		let lpBalance2 = reserveData2.reserve1.mul(ba2).div(reserve2Total);

		let balsnap3 = await uwu.balanceOf(user, { blockTag: snap3 });
		let earned1snap3 = await uwuMining.earned(user, { blockTag: snap3 });
		let earned2snap3 = await debaseBridge.earned(user, { blockTag: snap3 });
		let earned3snap3 = await debaseDaiBridge.earned(user, { blockTag: snap3 });
		let ba3 = await pair.balanceOf(user, { blockTag: snap3 });
		let lpBalance3 = reserveData3.reserve1.mul(ba3).div(reserve3Total);

		console.log(
			formatEther(balsnap1),
			earned1snap1,
			earned2snap1,
			earned3snap1,
			ba1,
			lpBalance,
			formatEther(balsnap2),
			formatEther(balsnap3)
		);

		console.log('JSON data is saved.');
	} catch (error) {
		console.error(error);
	}
}

main().then(() => process.exit(0)).catch((error) => {
	console.error(error);
	process.exit(1);
});
