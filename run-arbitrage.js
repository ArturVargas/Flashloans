require('dotenv').config();
const Web3 = require('web3');
const { ChainId, TokenAmount, Fetcher } = require('@uniswap/sdk');

const abis = require('./abis');
const { mainnet: addresses } = require('./addresses');

const web3 = new Web3(
  new Web3.providers.WebsocketProvider(`wss://mainnet.infura.io/ws/v3/${process.env.PROJECT_ID}`)
);

const kyber = new web3.eth.Contract(
  abis.kyber.kyberNetworkProxy,
  addresses.kyber.kyberNetworkProxy
);

const AMOUNT_ETH = 100;
const RECENT_ETH_PRICE = 1329;
const AMOUNT_ETH_WEI = web3.utils.toWei(AMOUNT_ETH.toString());
const AMOUNT_DAI_WEI = web3.utils.toWei((AMOUNT_ETH * RECENT_ETH_PRICE).toString());

const init = async () => {
  const daiTokenAddress = addresses.tokens.dai;
  const wethTokenAddress = addresses.tokens.weth;

  const dai = await Fetcher.fetchTokenData(
    ChainId.MAINNET,
    daiTokenAddress,
    undefined,
    'DAI',
    'Dai Stablecoin'
  );

  const weth = await Fetcher.fetchTokenData(
    ChainId.MAINNET,
    wethTokenAddress,
    undefined,
    'WETH'
  );

  const daiWeth = await Fetcher.fetchPairData(dai, weth);

  web3.eth.subscribe('newBlockHeaders')
  .on('data', async (block) => {
    console.log(`New Block received. Block # ${block.number}`);
    const kyberResult = await Promise.all([
      kyber.methods.getExpectedRate(
        addresses.tokens.dai,
        '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
        AMOUNT_DAI_WEI
      )
      .call(),
      kyber.methods.getExpectedRate(
        '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
        addresses.tokens.dai,
        AMOUNT_ETH_WEI
      )
      .call()
    ]);
    const kyberRates = {
      buy: parseFloat(1 / (kyberResult[0].expectedRate / (10 ** 18))),
      sell: parseFloat(kyberResult[1].expectedRate / (10 ** 18))
    };
    console.log('Kyber ETH/DAI: ', kyberRates);

    const uniswapResults = await Promise.all([
      daiWeth.getOutputAmount(new TokenAmount(dai, AMOUNT_DAI_WEI)),
      daiWeth.getOutputAmount(new TokenAmount(weth, AMOUNT_ETH_WEI))
    ]);
    
    const uniswapRates = {
      buy: parseFloat(AMOUNT_DAI_WEI / (uniswapResults[0][0].toExact() * (10 ** 18))),
      sell: parseFloat(uniswapResults[1][0].toExact() / AMOUNT_ETH)
    };

    console.log('Uniswap ETH/DAI: ', uniswapRates);

    const gasPrice = await web3.eth.getGasPrice();
    const txCost = 200000 * parseInt(gasPrice);
    const currentEthPrice = (uniswapRates.buy + uniswapRates.sell) / 2;
    const profit1 = (parseInt(AMOUNT_ETH_WEI) / 10 ** 18) * (uniswapRates.sell - kyberRates.buy) - (txCost / 10 ** 18) * currentEthPrice;
    const profit2 = (parseInt(AMOUNT_ETH_WEI) / 10 ** 18) * (kyberRates.sell - uniswapRates.buy) - (txCost / 10 ** 18) * currentEthPrice;

    if(profit1 > 0) {
      console.log('Arbitrage opportunity...');
      console.log(`Buy ETH on Kyber at ${kyberRates.buy} dai`);
      console.log(`Sell ETH on Uniswap at ${uniswapRates.sell} dai`);
      console.log(`Expected profit: ${profit1} dai`);
    } else if(profit2 > 0) {
      console.log('Arbitrage opportunity...');
      console.log(`Buy ETH on Uniswap at ${uniswapRates.buy} dai`);
      console.log(`Sell ETH on Kyber at ${kyberRates.sell} dai`);
      console.log(`Expected profit: ${profit2} dai`);
    }
  })
  .on('error', (error) => {
    console.log(error);
  });
};

init();
