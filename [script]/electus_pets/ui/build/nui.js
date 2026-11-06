// This script was leaked inside at TCHub Website so check that out https://tchub.st/dashboard

(() => {
    const emptyResult = (name) => {
        switch (name) {
            case 'loadUtils': return null;
            case 'getEmotes':
            case 'getSniffedItems':
            case 'getSniffableItems':
            case 'getAvaliableFriendJobs': return [];
            case 'getFriends': return { players: [], jobs: [] };
            case 'getAccessoriesData': return { slots: [], inventory: [] };
            case 'getCompatibiles': return { comp: {}, labels: {} };
            case 'getHouseData': return { house: [], outside: [], maxOutside: 0, maxHouseSlots: 0 };
            default: return {};
        }
    };

    window.electusPetsNuiRequest = async (name, data) => {
        const attempts = name === 'loadUtils' ? 20 : 1;
        for (let attempt = 0; attempt < attempts; attempt++) {
          try {
            const resource = window.GetParentResourceName ? window.GetParentResourceName() : 'electus_pets';
            const response = await fetch(`https://${resource}/${name}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify(data ?? {}),
            });
            if (!response.ok) throw new Error(`HTTP ${response.status}`);
            const body = await response.text();
            if (!body.trim()) throw new Error('callback returned an empty response');
            let result;
            try { result = JSON.parse(body); }
            catch { throw new Error('callback returned invalid JSON'); }
            if (result && result.error) throw new Error(result.error);
            return result;
          } catch (error) {
            if (attempt + 1 < attempts) {
                await new Promise((resolve) => setTimeout(resolve, 250));
                continue;
            }
            console.error(`[electus_pets] NUI ${name}: ${error.message}`);
            return emptyResult(name);
          }
        }
    };
})();
