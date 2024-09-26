using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteAlways]
public class DetectionComponent : MonoBehaviour
{
    public float m_radius = 1.0f;
    public LayerMask m_layerMask;
    public float m_depthFactor = 1.0f;
    public float m_contactRadius = 1.0f;
    
    private Vector3 m_startPoint;
    private Vector3 m_endPoint;

    private void OnEnable()
    {
        TrailsManager.Get()?.RegisterFootprint(this);
    }

    private void OnDisable()
    {
        TrailsManager.Get()?.RemoveFootprint(this);
    }

    public void GenerateFootprint()
    {
        m_startPoint = transform.position;
        m_endPoint = m_startPoint + (2 * m_radius) * Vector3.up * (-1);
        if (Physics.Linecast(m_startPoint, m_endPoint, out var hit, m_layerMask))
        {
            var footPoint = new Footprint();
            
            Vector3 hitPoint = hit.point;
            var distance = Vector3.Distance(m_startPoint, hitPoint);
            var depth = ((2 * m_radius) - distance) ;
            var contactRadius = Mathf.Sqrt(m_radius * m_radius - (m_radius - depth) * (m_radius - depth));

            footPoint.LocalPosition = transform.localPosition;
            footPoint.HitPoint = hitPoint;
            footPoint.Depth = depth * m_depthFactor;
            footPoint.ContactRadius = contactRadius * m_contactRadius;

            var position = transform.position;
            var trailPosition = TrailsManager.Get()?.m_trailTextureTransform.position ?? Vector3.zero;
            var localPosition = position - trailPosition;
            
            // [-1, 1]
            float x = localPosition.x / TrailsManager.Get()?.m_trailTextureSize ?? 0.0f;
            float y = localPosition.z / TrailsManager.Get()?.m_trailTextureSize ?? 0.0f;
            
            footPoint.UV = new Vector2(1.0f - (x * 0.5f + 0.5f), 1.0f - (y * 0.5f + 0.5f));
            
            TrailsManager.Get().AddFootprint(footPoint);
        }
    }

    private void OnDrawGizmos()
    {
        Gizmos.color = Color.red;
        Gizmos.DrawLine(m_startPoint, m_endPoint);
    }
}
