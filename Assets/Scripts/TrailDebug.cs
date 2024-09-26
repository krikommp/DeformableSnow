using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteAlways]
public class TrailDebug : MonoBehaviour
{
    public GameObject m_player;
    public bool m_followPlayer = true;

    void Update()
    {
        if (!m_followPlayer)
        {
            return;
        }
        
        if (m_player == null)
        {
            Debug.LogError("Player is not set");
        }
        else
        {
            var playerPosition = m_player.transform.position;
            var selfPosition = transform.position;

            transform.position = new Vector3(playerPosition.x, selfPosition.y, playerPosition.z);
        }
    }
}
