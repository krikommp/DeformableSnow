using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

[ExecuteAlways]
public class TrailsManager : MonoBehaviour
{
    private static TrailsManager s_instance;

    public static TrailsManager Get()
    {
        if (s_instance == null)
            s_instance = FindObjectOfType<TrailsManager>();

        return s_instance;
    }

    private List<DetectionComponent> m_detectionComponents = new List<DetectionComponent>();
    private List<Footprint> m_footprints = new List<Footprint>();
    private Vector3 m_lastPosition;
    private Vector3 m_currentPosition;

    public Shader m_footprintShader;
    private Material m_footprintMaterial;
    public RenderTexture m_footprintTexture;

    public Material m_trailMaterial;
    public RenderTexture m_currentTexture;
    public RenderTexture m_trailsTexture;
    public RenderTexture m_historyTexture;

    public float m_footprintSize = 20.0f;

    public Transform m_trailTextureTransform;
    public float m_trailTextureSize;
    public Vector2 m_trailTextureResolution = new Vector2(1024, 1024);

    private void OnEnable()
    {
        m_footprintTexture = new RenderTexture(128, 128, 0, RenderTextureFormat.ARGB32);
        m_lastPosition = m_currentPosition = m_trailTextureTransform.position;
        
        ClearTexture(m_historyTexture);
    }

    private void OnDisable()
    {
        m_footprintTexture.Release();
    }

    public void RegisterFootprint(DetectionComponent detectionComponent)
    {
        if (detectionComponent == null)
            return;

        m_detectionComponents.Add(detectionComponent);
    }

    public void RemoveFootprint(DetectionComponent detectionComponent)
    {
        if (detectionComponent == null)
            return;

        m_detectionComponents.Remove(detectionComponent);
    }

    public void AddFootprint(Footprint footprint)
    {
        m_footprints.Add(footprint);
    }

    private void Update()
    {
        UpdateLocation();
        m_footprints.Clear();
        ClearTexture(m_currentTexture);

        foreach (var detectionComponent in m_detectionComponents)
        {
            detectionComponent.GenerateFootprint();
        }

        foreach (var footprint in m_footprints)
        {
            RenderFootprint(footprint);
        }
        
        SetupSnowParameters();
        DrawTrailTexture();
        DrawHistoryTexture();
        DrawBlurTrail();
        SetupTerrainParameters();
    }

    private void RenderFootprint(Footprint footprint)
    {
        if (m_footprintShader == null)
        {
            Debug.LogError("Footprint shader is null");
            return;
        }
        
        if (m_footprintMaterial == null)
        {
            m_footprintMaterial = new Material(m_footprintShader);
        }

        m_footprintMaterial.SetFloat("_FootprintDepth", footprint.Depth);
        Graphics.Blit(null, m_footprintTexture, m_footprintMaterial);

        RenderFootprintToCurrentTexture(m_footprintTexture, footprint);
    }

    private void ClearTexture(RenderTexture renderTexture)
    {
        if (renderTexture == null)
        {
            Debug.LogError("Current texture is null");
            return;
        }

        var cmd = CommandBufferPool.Get("Clear Tail Texture");

        cmd.SetRenderTarget(renderTexture);
        cmd.ClearRenderTarget(true, true, Color.black);

        Graphics.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    private void RenderFootprintToCurrentTexture(RenderTexture footprintTexture, Footprint footprint)
    {
        if (m_trailMaterial == null)
        {
            Debug.LogError("Trail material is null");
            return;
        }

        if (m_currentTexture == null)
        {
            Debug.LogError("Current texture is null");
            return;
        }

        float width = (footprint.ContactRadius * 2) * m_footprintSize;
        float height = (footprint.ContactRadius * 2) * m_footprintSize;
        float halfWidth = width * 0.5f;
        float halfHeight = height * 0.5f;

        var cmd = CommandBufferPool.Get("Render Footprint");
        Rect viewport = new Rect(m_currentTexture.width * footprint.UV.x - halfWidth,
            m_currentTexture.height * footprint.UV.y - halfHeight, width, height);
        cmd.SetRenderTarget(m_currentTexture);
        cmd.SetViewport(viewport);
        m_trailMaterial.SetTexture("_FootprintTexture", footprintTexture);
        cmd.DrawProcedural(Matrix4x4.identity, m_trailMaterial, 0, MeshTopology.Triangles, 3, 1, null);

        Graphics.ExecuteCommandBuffer(cmd);

        CommandBufferPool.Release(cmd);
    }

    private void SetupSnowParameters()
    {
        var cmd = CommandBufferPool.Get("Setup Snow Parameters");

        var trailPosition = m_trailTextureTransform.position;
        cmd.SetGlobalVector("_PostionSize", new Vector4(trailPosition.x, trailPosition.z, m_trailTextureSize, m_trailTextureSize));
        
        Graphics.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }
    
    private void DrawTrailTexture()
    {
        if (m_trailMaterial == null)
        {
            Debug.LogError("Trail material is null");
            return;
        }
        
        ClearTexture(m_trailsTexture);

        var cmd = CommandBufferPool.Get("Draw Trail Texture");
        
        var offset = m_currentPosition - m_lastPosition;
        offset /= 2 * m_trailTextureSize;
     
        cmd.SetRenderTarget(m_trailsTexture);
        m_trailMaterial.SetTexture("_HistoryTexture", m_historyTexture);
        m_trailMaterial.SetTexture("_CurrentTexture", m_currentTexture);
        m_trailMaterial.SetVector("_HistoryOffset", new Vector4(offset.x, offset.z, 0.0f, 0.0f));
        cmd.DrawProcedural(Matrix4x4.identity, m_trailMaterial, 1, MeshTopology.Triangles, 3, 1, null);
        
        Graphics.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    private void DrawHistoryTexture()
    {
        if (m_trailMaterial == null)
        {
            Debug.LogError("Trail material is null");
            return;
        }
        
        var cmd = CommandBufferPool.Get("Draw History Texture");
     
        cmd.SetRenderTarget(m_historyTexture);
        m_trailMaterial.SetTexture("_TrailTexture", m_trailsTexture);
        cmd.DrawProcedural(Matrix4x4.identity, m_trailMaterial, 2, MeshTopology.Triangles, 3, 1, null);
        
        
        Graphics.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    private void DrawBlurTrail()
    {
        
    }

    private void UpdateLocation()
    {
        m_lastPosition = m_currentPosition;
        m_currentPosition = m_trailTextureTransform.position;

        var position = m_trailTextureTransform.position;
        var size = new Vector2(m_trailTextureSize * 2.0f, m_trailTextureSize * 2.0f);
        var locationCalcHelper = size / m_trailTextureResolution;
        
        m_currentPosition = new Vector3(
            Mathf.Floor(position.x / locationCalcHelper.x) * locationCalcHelper.x, 
            position.y, 
            Mathf.Floor(position.z / locationCalcHelper.y) * locationCalcHelper.y);
    }

    private void SetupTerrainParameters()
    {
        var cmd = CommandBufferPool.Get("Setup Terrain Parameters");

        var position = m_trailTextureTransform.position;
        cmd.SetGlobalVector("_TrailLocation", new Vector4(position.x, position.y, position.z, m_trailTextureSize));
        
        Graphics.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }
}