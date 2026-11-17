export const activateProject = async (functionUrl: string, siteUrl: string, setActivating: React.Dispatch<React.SetStateAction<boolean>>): Promise<number> => {
    setActivating(true);

    const response = await fetch(functionUrl, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            Url: siteUrl,
            Status: 'Aktivt'
        })
    });

    setActivating(false);
    return response.status;
}