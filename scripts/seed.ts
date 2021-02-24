import { ethers } from 'hardhat';

import SeedFactoryArtifact from '../artifacts/contracts/Seed.sol/Seed.json';
import IUniswapV2PairArtifact from '../artifacts/@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol/IUniswapV2Pair.json';
import ERC20Artifact from '../artifacts/@openzeppelin/contracts/token/ERC20/ERC20.sol/ERC20.json';
import { SeedFactory } from '../type/SeedFactory';
import { Erc20 } from '../type/Erc20';
import { IUniswapV2Pair } from '../type/IUniswapV2Pair';

import { parseEther, parseUnits } from 'ethers/lib/utils';
import { BigNumber } from 'ethers';

async function main() {
	const signer = await ethers.getSigners();
	const account = await signer[0].getAddress();

	try {
		const UwU = new ethers.Contract('', ERC20Artifact.abi, signer[0]) as Erc20;
		const BNB = new ethers.Contract('', ERC20Artifact.abi, signer[0]) as Erc20;

		const uwuDistribution = parseEther('20000');
		const seedCap = parseEther('750000');
		const walletCapPercentage = 5;
		const scale = parseEther('1');

		const uniswapV2Pair = new ethers.Contract('', IUniswapV2PairArtifact.abi, signer[0]) as IUniswapV2Pair;
		const data = await uniswapV2Pair.getReserves();

		const currentPrice = data.reserve1.div(data.reserve0).mul(scale);
		const bnbCap = seedCap.div(currentPrice);
		const walletCap = bnbCap.mul(walletCapPercentage).div(100);
		const tokenExchangeRate = uwuDistribution.div(bnbCap);

		const seedFactory = (new ethers.ContractFactory(
			SeedFactoryArtifact.abi,
			SeedFactoryArtifact.bytecode,
			signer[0]
		) as any) as SeedFactory;

		const seed = await seedFactory.deploy(
			UwU.address,
			BNB.address,
			bnbCap,
			walletCap,
			currentPrice,
			tokenExchangeRate
		);

		console.log(seed.address);
	} catch (error) {
		console.error(error);
	}
}

main().then(() => process.exit(0)).catch((error) => {
	console.error(error);
	process.exit(1);
});
