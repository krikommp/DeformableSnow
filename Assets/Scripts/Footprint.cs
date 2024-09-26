using UnityEngine;

public class Footprint
{
    public Vector3 LocalPosition { get; set; }
    public Vector3 HitPoint { get; set; }
    public float Depth { get; set; }
    public float ContactRadius { get; set; }
    public Vector2 UV { get; set; }
    
    public override string ToString()
    {
        return $"LocalPosition: {LocalPosition}, HitPoint: {HitPoint}, Depth: {Depth}, ContactRadius: {ContactRadius}";
    }
}