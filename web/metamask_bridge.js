// Jembatan EIP-1193 MetaMask Provider untuk Flutter Web
window.chainTodoMetaMask = {
  isAvailable: function() {
    return typeof window.ethereum !== 'undefined' && Boolean(window.ethereum.isMetaMask);
  },

  requestAccounts: async function() {
    if (!window.ethereum) {
      throw new Error("MetaMask Extension tidak terdeteksi. Silakan aktifkan MetaMask pada Google Chrome.");
    }
    const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
    return accounts;
  },

  getChainId: async function() {
    if (!window.ethereum) return null;
    return await window.ethereum.request({ method: 'eth_chainId' });
  },

  switchChainToSepolia: async function() {
    if (!window.ethereum) {
      throw new Error("MetaMask Extension tidak terdeteksi.");
    }
    const sepoliaChainIdHex = '0xaa36a7'; // 11155111 dalam hexadecimal
    try {
      await window.ethereum.request({
        method: 'wallet_switchEthereumChain',
        params: [{ chainId: sepoliaChainIdHex }],
      });
      return true;
    } catch (switchError) {
      // Error code 4902: Jaringan belum ada di MetaMask pengguna
      if (switchError.code === 4902 || switchError.data?.originalError?.code === 4902) {
        await window.ethereum.request({
          method: 'wallet_addEthereumChain',
          params: [{
            chainId: sepoliaChainIdHex,
            chainName: 'Ethereum Sepolia Testnet',
            nativeCurrency: { name: 'Sepolia Ether', symbol: 'ETH', decimals: 18 },
            rpcUrls: ['https://rpc.sepolia.org', 'https://ethereum-sepolia-rpc.publicnode.com'],
            blockExplorerUrls: ['https://sepolia.etherscan.io'],
          }],
        });
        return true;
      }
      throw switchError;
    }
  },

  sendTransaction: async function(from, to, dataHex) {
    if (!window.ethereum) {
      throw new Error("MetaMask Extension tidak terdeteksi.");
    }
    const params = [{
      from: from,
      to: to,
      data: dataHex,
    }];
    const txHash = await window.ethereum.request({
      method: 'eth_sendTransaction',
      params: params,
    });
    return txHash;
  },

  onAccountsChanged: function(callback) {
    if (window.ethereum) {
      window.ethereum.on('accountsChanged', function(accounts) {
        if (typeof callback === 'function') {
          callback(accounts);
        }
      });
    }
  },

  onChainChanged: function(callback) {
    if (window.ethereum) {
      window.ethereum.on('chainChanged', function(chainId) {
        if (typeof callback === 'function') {
          callback(chainId);
        }
      });
    }
  }
};

